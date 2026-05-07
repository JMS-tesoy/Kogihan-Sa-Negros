## Finding large file size code ##

Get-ChildItem -Path lib -Recurse -Include *.dart |
ForEach-Object {
    $lineCount = (Get-Content $_.FullName | Measure-Object -Line).Lines
    [PSCustomObject]@{
        Lines = $lineCount
        SizeKB = [math]::Round($_.Length / 1KB, 2)
        File = $_.FullName.Replace((Get-Location).Path + "\", "")
    }
} |
Sort-Object Lines -Descending |
Format-Table -AutoSize




or this command


Get-ChildItem -Path lib -Recurse -Include *.dart | ForEach-Object { $lineCount = (Get-Content $_.FullName | Measure-Object -Line).Lines; [PSCustomObject]@{ Lines = $lineCount; SizeKB = [math]::Round($_.Length / 1KB, 2); File = $_.FullName.Replace((Get-Location).Path + "\", "") } } | Sort-Object Lines -Descending | Format-Table -AutoSize
## --------------------------------------------------------------------------------------------------##


Two debug mode instance:

flutter run -d emulator-5554     --emulator

flutter run -d AWCX6R4329007755   ---real phone
