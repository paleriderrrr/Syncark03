param(
	[string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$uiDir = Join-Path $ProjectRoot "Art\\UI"
$outDir = Join-Path $uiDir "Slices"
if (-not (Test-Path $outDir)) {
	New-Item -ItemType Directory -Path $outDir | Out-Null
}

$specs = @{
	"UI1-2.png" = @(
		@{ Name = "ui1_2_settings_icon"; X = 3; Y = 4; W = 118; H = 119 }
		@{ Name = "ui1_2_help_icon"; X = 259; Y = 3; W = 111; H = 115 }
		@{ Name = "ui1_2_coin_marker"; X = 515; Y = 2; W = 80; H = 78 }
		@{ Name = "ui1_2_depart_sign"; X = 771; Y = 2; W = 384; H = 199 }
		@{ Name = "ui1_2_role_tab_top"; X = 0; Y = 316; W = 405; H = 167 }
		@{ Name = "ui1_2_role_tab_mid"; X = 0; Y = 514; W = 432; H = 228 }
		@{ Name = "ui1_2_role_tab_bottom"; X = 0; Y = 828; W = 419; H = 158 }
		@{ Name = "ui1_2_board_wood"; X = 541; Y = 266; W = 1070; H = 681 }
		@{ Name = "ui1_2_right_board"; X = 1792; Y = 12; W = 573; H = 441 }
		@{ Name = "ui1_2_wanted_poster"; X = 1794; Y = 512; W = 233; H = 308 }
		@{ Name = "ui1_2_category_fruit"; X = 2304; Y = 512; W = 61; H = 65 }
		@{ Name = "ui1_2_category_dessert"; X = 2561; Y = 513; W = 72; H = 62 }
		@{ Name = "ui1_2_category_meat"; X = 2816; Y = 513; W = 59; H = 70 }
		@{ Name = "ui1_2_category_drink"; X = 2304; Y = 768; W = 69; H = 67 }
		@{ Name = "ui1_2_category_staple"; X = 2560; Y = 768; W = 66; H = 54 }
		@{ Name = "ui1_2_category_spice"; X = 2816; Y = 768; W = 74; H = 83 }
	)
	"UI2-2.png" = @(
		@{ Name = "ui2_2_panel_top_green"; X = 0; Y = 0; W = 1389; H = 338 }
		@{ Name = "ui2_2_panel_bottom_red"; X = 3; Y = 422; W = 1651; H = 346 }
		@{ Name = "ui2_2_badge_red_square"; X = 0; Y = 884; W = 139; H = 140 }
		@{ Name = "ui2_2_badge_green_square"; X = 255; Y = 884; W = 140; H = 140 }
		@{ Name = "ui2_2_badge_wide_light"; X = 511; Y = 897; W = 228; H = 125 }
		@{ Name = "ui2_2_badge_small_light"; X = 766; Y = 966; W = 123; H = 58 }
		@{ Name = "ui2_2_badge_small_dark"; X = 1022; Y = 965; W = 124; H = 59 }
	)
}

function Test-IsBackgroundColor {
	param([System.Drawing.Color]$Color)

	return $Color.A -le 16 -or ($Color.R -le 18 -and $Color.G -le 18 -and $Color.B -le 18)
}

function Remove-EdgeBackground {
	param([System.Drawing.Bitmap]$Bitmap)

	$width = $Bitmap.Width
	$height = $Bitmap.Height
	$visited = New-Object "System.Collections.BitArray" ($width * $height)
	$queue = New-Object "System.Collections.Generic.Queue[System.Drawing.Point]"

	for ($x = 0; $x -lt $width; $x++) {
		$queue.Enqueue([System.Drawing.Point]::new($x, 0))
		$queue.Enqueue([System.Drawing.Point]::new($x, $height - 1))
	}
	for ($y = 1; $y -lt ($height - 1); $y++) {
		$queue.Enqueue([System.Drawing.Point]::new(0, $y))
		$queue.Enqueue([System.Drawing.Point]::new($width - 1, $y))
	}

	while ($queue.Count -gt 0) {
		$point = $queue.Dequeue()
		$x = $point.X
		$y = $point.Y
		if ($x -lt 0 -or $y -lt 0 -or $x -ge $width -or $y -ge $height) {
			continue
		}
		$index = $y * $width + $x
		if ($visited[$index]) {
			continue
		}
		$visited[$index] = $true

		$color = $Bitmap.GetPixel($x, $y)
		if (-not (Test-IsBackgroundColor $color)) {
			continue
		}

		$Bitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0))
		$queue.Enqueue([System.Drawing.Point]::new($x + 1, $y))
		$queue.Enqueue([System.Drawing.Point]::new($x - 1, $y))
		$queue.Enqueue([System.Drawing.Point]::new($x, $y + 1))
		$queue.Enqueue([System.Drawing.Point]::new($x, $y - 1))
	}
}

foreach ($atlasName in $specs.Keys) {
	$atlasPath = Join-Path $uiDir $atlasName
	$atlas = [System.Drawing.Bitmap]::new($atlasPath)
	try {
		foreach ($spec in $specs[$atlasName]) {
			$rect = [System.Drawing.Rectangle]::new($spec.X, $spec.Y, $spec.W, $spec.H)
			$crop = $atlas.Clone($rect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
			try {
				Remove-EdgeBackground -Bitmap $crop
				$outPath = Join-Path $outDir ($spec.Name + ".png")
				$crop.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
				Write-Output $outPath
			}
			finally {
				$crop.Dispose()
			}
		}
	}
	finally {
		$atlas.Dispose()
	}
}
