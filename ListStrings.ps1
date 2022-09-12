# Generate locale files from the source

Import-Module ..\..\AddonUploader

Update-Localization -SourceMask 'XKey*.lua'

Remove-Module AddonUploader
