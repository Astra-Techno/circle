# Mechanical platform-size exports of the complete owner-supplied artwork.
# No crop, recolouring, lettering substitution or generated artwork.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$mobileRoot = Split-Path -Parent $PSScriptRoot
$source = [Drawing.Image]::FromFile((Join-Path $mobileRoot 'assets/brand/circle-brand.png'))
function Export-BrandIcon([string]$relativePath, [int]$size) {
    $bitmap = [Drawing.Bitmap]::new($size, $size, [Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.DrawImage($source, [Drawing.Rectangle]::new(0, 0, $size, $size))
        $bitmap.Save((Join-Path $mobileRoot $relativePath), [Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}
try {
    foreach ($entry in @{mdpi=48; hdpi=72; xhdpi=96; xxhdpi=144; xxxhdpi=192}.GetEnumerator()) {
        Export-BrandIcon "android/app/src/main/res/mipmap-$($entry.Key)/ic_launcher.png" $entry.Value
    }
    $catalog = Get-Content (Join-Path $mobileRoot 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json') -Raw | ConvertFrom-Json
    foreach ($entry in $catalog.images) {
        $size = [int](([double]($entry.size.Split('x')[0])) * ([double]($entry.scale.TrimEnd('x'))))
        Export-BrandIcon "ios/Runner/Assets.xcassets/AppIcon.appiconset/$($entry.filename)" $size
    }
    Export-BrandIcon 'web/favicon.png' 32
    foreach ($size in @(192, 512)) {
        Export-BrandIcon "web/icons/Icon-$size.png" $size
        Export-BrandIcon "web/icons/Icon-maskable-$size.png" $size
    }
} finally {
    $source.Dispose()
}
