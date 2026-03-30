param(
    [string[]]$DefinitionIds = @(),
    [int]$CellSize = 72
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$Root = Split-Path -Parent $PSScriptRoot
$CatalogPath = Join-Path $Root "Data/Foods/food_catalog.tres"
$FoodDir = Join-Path $Root "Art/Food"
$OutputDir = Join-Path $Root "Art/FoodBoard"

function Get-FoodDefinitions {
    param([string]$Path)

    $content = Get-Content -Path $Path -Raw -Encoding UTF8
    $blockPattern = '\[sub_resource type="Resource" id="[^"]+"\](.*?)(?=\r?\n\[sub_resource|\r?\nfoods = \[|\z)'
    $definitions = @{}
    foreach ($match in [System.Text.RegularExpressions.Regex]::Matches($content, $blockPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
        $block = $match.Groups[1].Value
        $idMatch = [System.Text.RegularExpressions.Regex]::Match($block, 'id = &"([^"]+)"')
        if (-not $idMatch.Success) {
            continue
        }
        $id = $idMatch.Groups[1].Value
        $cells = New-Object System.Collections.Generic.List[object]
        foreach ($cellMatch in [System.Text.RegularExpressions.Regex]::Matches($block, 'Vector2i\((-?\d+),\s*(-?\d+)\)')) {
            $cells.Add([pscustomobject]@{
                X = [int]$cellMatch.Groups[1].Value
                Y = [int]$cellMatch.Groups[2].Value
            })
        }
        $definitions[$id] = $cells.ToArray()
    }
    return $definitions
}

function Get-FoodImageLookup {
    param([string]$Path)

    $lookup = @{}
    Get-ChildItem -Path $Path -File | Where-Object { $_.Extension.ToLowerInvariant() -eq ".png" -and -not $_.BaseName.StartsWith("IMG_", [System.StringComparison]::OrdinalIgnoreCase) } | ForEach-Object {
        $lookup[$_.BaseName.ToLowerInvariant()] = $_.FullName
    }
    return $lookup
}

function Rotate-NormalizeCells {
    param(
        [object[]]$Cells,
        [int]$Steps
    )

    $normalizedSteps = (($Steps % 4) + 4) % 4
    $rotated = New-Object System.Collections.Generic.List[object]
    foreach ($cell in $Cells) {
        $x = [int]$cell.X
        $y = [int]$cell.Y
        for ($i = 0; $i -lt $normalizedSteps; $i++) {
            $nextX = -$y
            $nextY = $x
            $x = $nextX
            $y = $nextY
        }
        $rotated.Add([pscustomobject]@{ X = $x; Y = $y })
    }
    if ($rotated.Count -eq 0) {
        return @()
    }
    $minX = ($rotated | Measure-Object -Property X -Minimum).Minimum
    $minY = ($rotated | Measure-Object -Property Y -Minimum).Minimum
    return $rotated | ForEach-Object {
        [pscustomobject]@{
            X = [int]$_.X - [int]$minX
            Y = [int]$_.Y - [int]$minY
        }
    } | Sort-Object Y, X
}

function Get-CellBounds {
    param([object[]]$Cells)

    if ($Cells.Count -eq 0) {
        return @{
            X = 0
            Y = 0
            Width = 0
            Height = 0
        }
    }
    $minX = ($Cells | Measure-Object -Property X -Minimum).Minimum
    $maxX = ($Cells | Measure-Object -Property X -Maximum).Maximum
    $minY = ($Cells | Measure-Object -Property Y -Minimum).Minimum
    $maxY = ($Cells | Measure-Object -Property Y -Maximum).Maximum
    return @{
        X = [int]$minX
        Y = [int]$minY
        Width = [int]$maxX - [int]$minX + 1
        Height = [int]$maxY - [int]$minY + 1
    }
}

function Get-VisibleAlphaRegion {
    param([System.Drawing.Bitmap]$Bitmap)

    $width = $Bitmap.Width
    $height = $Bitmap.Height
    $minX = $width
    $maxX = -1
    $minY = $height
    $maxY = -1
    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
            if ($Bitmap.GetPixel($x, $y).A -le 5) {
                continue
            }
            if ($x -lt $minX) { $minX = $x }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
    if ($maxX -lt $minX -or $maxY -lt $minY) {
        return @{
            X = 0.0
            Y = 0.0
            Width = [double]$width
            Height = [double]$height
            EndX = [double]$width
            EndY = [double]$height
        }
    }
    return @{
        X = [double]$minX
        Y = [double]$minY
        Width = [double]($maxX - $minX + 1)
        Height = [double]($maxY - $minY + 1)
        EndX = [double]($maxX + 1)
        EndY = [double]($maxY + 1)
    }
}

function Resolve-BoundedStretchPair {
    param(
        [double]$RatioMultiplier,
        [double]$Low,
        [double]$High
    )

    if ($RatioMultiplier -le 0.0) {
        return @{ X = 1.0; Y = 1.0 }
    }
    $symmetricX = [Math]::Sqrt($RatioMultiplier)
    $symmetricY = 1.0 / $symmetricX
    if ($symmetricX -ge $Low -and $symmetricX -le $High -and $symmetricY -ge $Low -and $symmetricY -le $High) {
        return @{ X = $symmetricX; Y = $symmetricY }
    }
    if ($RatioMultiplier -gt 1.0) {
        return @{ X = $High; Y = $High / $RatioMultiplier }
    }
    return @{ X = $High * $RatioMultiplier; Y = $High }
}

function Test-IsEqualApprox {
    param(
        [double]$A,
        [double]$B
    )

    return [Math]::Abs($A - $B) -le 1e-5
}

function Compute-BestZeroCropSolution {
    param(
        [double]$SourceWidth,
        [double]$SourceHeight,
        [double]$TargetWidth,
        [double]$TargetHeight,
        [double]$StretchLimit = 0.2
    )

    if ($SourceWidth -le 0.0 -or $SourceHeight -le 0.0 -or $TargetWidth -le 0.0 -or $TargetHeight -le 0.0) {
        return @{
            RotationRadians = 0.0
            ScaleX = 1.0
            ScaleY = 1.0
            ContainScale = 1.0
            DestX = 0.0
            DestY = 0.0
            DestWidth = $TargetWidth
            DestHeight = $TargetHeight
        }
    }

    $low = [Math]::Max(0.0, 1.0 - $StretchLimit)
    $high = 1.0 + $StretchLimit
    $sourceRatio = $SourceWidth / $SourceHeight
    $targetRatio = $TargetWidth / $TargetHeight
    $ratioLow = $sourceRatio * ($low / $high)
    $ratioHigh = $sourceRatio * ($high / $low)
    $solvedRatio = [Math]::Min([Math]::Max($targetRatio, $ratioLow), $ratioHigh)
    $ratioMultiplier = $solvedRatio / $sourceRatio
    $stretch = Resolve-BoundedStretchPair -RatioMultiplier $ratioMultiplier -Low $low -High $high
    $adjustedWidth = $SourceWidth * $stretch.X
    $adjustedHeight = $SourceHeight * $stretch.Y
    $containScale = [Math]::Min($TargetWidth / $adjustedWidth, $TargetHeight / $adjustedHeight)
    $fittedWidth = $adjustedWidth * $containScale
    $fittedHeight = $adjustedHeight * $containScale
    $best = @{
        RotationRadians = 0.0
        ScaleX = 1.0
        ScaleY = 1.0
        ContainScale = $containScale
        DestX = ($TargetWidth - $fittedWidth) * 0.5
        DestY = ($TargetHeight - $fittedHeight) * 0.5
        DestWidth = $fittedWidth
        DestHeight = $fittedHeight
    }
    $bestSubjectArea = -1.0
    $bestBboxArea = -1.0
    $bestDistortion = [double]::PositiveInfinity

    for ($angleStep = 0; $angleStep -le 360; $angleStep++) {
        $angle = ([Math]::PI * 0.5) * ($angleStep / 360.0)
        $cosine = [Math]::Abs([Math]::Cos($angle))
        $sine = [Math]::Abs([Math]::Sin($angle))
        for ($stretchXStep = 0; $stretchXStep -le 20; $stretchXStep++) {
            $scaleX = $low + ($high - $low) * ($stretchXStep / 20.0)
            for ($stretchYStep = 0; $stretchYStep -le 20; $stretchYStep++) {
                $scaleY = $low + ($high - $low) * ($stretchYStep / 20.0)
                $rotatedWidth = $SourceWidth * $scaleX * $cosine + $SourceHeight * $scaleY * $sine
                $rotatedHeight = $SourceWidth * $scaleX * $sine + $SourceHeight * $scaleY * $cosine
                if ($rotatedWidth -le 0.0 -or $rotatedHeight -le 0.0) {
                    continue
                }
                $candidateContainScale = [Math]::Min($TargetWidth / $rotatedWidth, $TargetHeight / $rotatedHeight)
                $fittedCandidateWidth = $rotatedWidth * $candidateContainScale
                $fittedCandidateHeight = $rotatedHeight * $candidateContainScale
                $subjectArea = $SourceWidth * $SourceHeight * $scaleX * $scaleY * $candidateContainScale * $candidateContainScale
                $bboxArea = $fittedCandidateWidth * $fittedCandidateHeight
                $distortion = [Math]::Abs($scaleX - 1.0) + [Math]::Abs($scaleY - 1.0)
                $beatsBest = $false
                if ($subjectArea -gt $bestSubjectArea + 0.0001) {
                    $beatsBest = $true
                } elseif ((Test-IsEqualApprox -A $subjectArea -B $bestSubjectArea) -and $bboxArea -gt $bestBboxArea + 0.0001) {
                    $beatsBest = $true
                } elseif ((Test-IsEqualApprox -A $subjectArea -B $bestSubjectArea) -and (Test-IsEqualApprox -A $bboxArea -B $bestBboxArea) -and $distortion -lt $bestDistortion - 0.0001) {
                    $beatsBest = $true
                }
                if (-not $beatsBest) {
                    continue
                }
                $bestSubjectArea = $subjectArea
                $bestBboxArea = $bboxArea
                $bestDistortion = $distortion
                $best = @{
                    RotationRadians = $angle
                    ScaleX = $scaleX
                    ScaleY = $scaleY
                    ContainScale = $candidateContainScale
                    DestX = ($TargetWidth - $fittedCandidateWidth) * 0.5
                    DestY = ($TargetHeight - $fittedCandidateHeight) * 0.5
                    DestWidth = $fittedCandidateWidth
                    DestHeight = $fittedCandidateHeight
                }
            }
        }
    }

    return $best
}

function New-BakedBitmap {
    param(
        [string]$SourcePath,
        [object[]]$ShapeCells,
        [int]$Rotation,
        [int]$BoardCellSize
    )

    $rotatedCells = Rotate-NormalizeCells -Cells $ShapeCells -Steps $Rotation
    $bounds = Get-CellBounds -Cells $rotatedCells
    $outputWidth = $bounds.Width * $BoardCellSize
    $outputHeight = $bounds.Height * $BoardCellSize
    if ($outputWidth -le 0 -or $outputHeight -le 0) {
        throw "Invalid output size for $SourcePath"
    }

    $sourceBitmap = [System.Drawing.Bitmap]::FromFile($SourcePath)
    try {
        $visibleRegion = Get-VisibleAlphaRegion -Bitmap $sourceBitmap
        $solution = Compute-BestZeroCropSolution -SourceWidth $visibleRegion.Width -SourceHeight $visibleRegion.Height -TargetWidth $outputWidth -TargetHeight $outputHeight
        $targetCenterX = $solution.DestX + $solution.DestWidth * 0.5
        $targetCenterY = $solution.DestY + $solution.DestHeight * 0.5
        $sourceCenterX = $visibleRegion.X + $visibleRegion.Width * 0.5
        $sourceCenterY = $visibleRegion.Y + $visibleRegion.Height * 0.5
        $containScale = [Math]::Max([double]$solution.ContainScale, 0.0001)
        $scaleX = [Math]::Max([double]$solution.ScaleX, 0.0001)
        $scaleY = [Math]::Max([double]$solution.ScaleY, 0.0001)
        $rotationRadians = [double]$solution.RotationRadians
        $cosine = [Math]::Cos($rotationRadians)
        $sine = [Math]::Sin($rotationRadians)

        $baked = New-Object System.Drawing.Bitmap($outputWidth, $outputHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        foreach ($cell in $rotatedCells) {
            $cellOriginX = [int]$cell.X * $BoardCellSize
            $cellOriginY = [int]$cell.Y * $BoardCellSize
            for ($localY = 0; $localY -lt $BoardCellSize; $localY++) {
                $pixelY = $cellOriginY + $localY
                $pixelPositionY = $pixelY + 0.5
                for ($localX = 0; $localX -lt $BoardCellSize; $localX++) {
                    $pixelX = $cellOriginX + $localX
                    $pixelPositionX = $pixelX + 0.5
                    if ($pixelPositionX -lt $solution.DestX -or $pixelPositionX -ge ($solution.DestX + $solution.DestWidth) -or $pixelPositionY -lt $solution.DestY -or $pixelPositionY -ge ($solution.DestY + $solution.DestHeight)) {
                        continue
                    }
                    $transformedX = ($pixelPositionX - $targetCenterX) / $containScale
                    $transformedY = ($pixelPositionY - $targetCenterY) / $containScale
                    $unrotatedX = $transformedX * $cosine + $transformedY * $sine
                    $unrotatedY = -$transformedX * $sine + $transformedY * $cosine
                    $sampleXFloat = $sourceCenterX + $unrotatedX / $scaleX
                    $sampleYFloat = $sourceCenterY + $unrotatedY / $scaleY
                    if ($sampleXFloat -lt $visibleRegion.X -or $sampleXFloat -ge $visibleRegion.EndX -or $sampleYFloat -lt $visibleRegion.Y -or $sampleYFloat -ge $visibleRegion.EndY) {
                        continue
                    }
                    $sampleX = [Math]::Max(0, [Math]::Min($sourceBitmap.Width - 1, [int][Math]::Floor($sampleXFloat)))
                    $sampleY = [Math]::Max(0, [Math]::Min($sourceBitmap.Height - 1, [int][Math]::Floor($sampleYFloat)))
                    $baked.SetPixel($pixelX, $pixelY, $sourceBitmap.GetPixel($sampleX, $sampleY))
                }
            }
        }
        return $baked
    } finally {
        $sourceBitmap.Dispose()
    }
}

function Save-Rotations {
    param(
        [System.Drawing.Bitmap]$BaseBitmap,
        [string]$DefinitionId,
        [string]$OutputPath
    )

    for ($rotation = 0; $rotation -lt 4; $rotation++) {
        $bitmap = $BaseBitmap.Clone()
        try {
            switch ($rotation) {
                1 { $bitmap.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone) }
                2 { $bitmap.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipNone) }
                3 { $bitmap.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipNone) }
            }
            $savePath = Join-Path $OutputPath ("{0}_r{1}.png" -f $DefinitionId, $rotation)
            $bitmap.Save($savePath, [System.Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $bitmap.Dispose()
        }
    }
}

$definitions = Get-FoodDefinitions -Path $CatalogPath
$foodImages = Get-FoodImageLookup -Path $FoodDir

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$targetIds = @()
if ($DefinitionIds.Count -gt 0) {
    $targetIds = $DefinitionIds
} else {
    $targetIds = $definitions.Keys | Sort-Object
}

$written = 0
foreach ($definitionId in $targetIds) {
    if (-not $definitions.ContainsKey($definitionId)) {
        throw "Unknown definition id: $definitionId"
    }
    if (-not $foodImages.ContainsKey($definitionId.ToLowerInvariant())) {
        throw "Missing source food image for: $definitionId"
    }
    $baseBitmap = New-BakedBitmap -SourcePath $foodImages[$definitionId.ToLowerInvariant()] -ShapeCells $definitions[$definitionId] -Rotation 0 -BoardCellSize $CellSize
    try {
        Save-Rotations -BaseBitmap $baseBitmap -DefinitionId $definitionId -OutputPath $OutputDir
        $written += 4
        Write-Host ("generated {0}_r0..r3.png" -f $definitionId)
    } finally {
        $baseBitmap.Dispose()
    }
}

Write-Host ("FOOD_BOARD_ASSETS_GENERATED {0}" -f $written)
