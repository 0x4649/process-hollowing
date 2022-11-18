# Process hollowing

Simple script to automate creating a powershell script that injects shellcode into a new `svchost` process.

## Usage

`PS > .\generate-script.ps1 <shellcode filename> <script filename>`

  **shellcode filename**: raw shellcode to inject,
  **script filename**: powershell script to create

## References

- [shelloader](https://github.com/john-xor/shelloader)
- [Inspecting a PowerShell Cobalt Strike Beacon](https://forensicitguy.github.io/inspecting-powershell-cobalt-strike-beacon/)
- [PowerShell Obfuscation](https://github.com/gh0x0st/Invoke-PSObfuscation/blob/main/layer-0-obfuscation.md)
- [Process Hollowing Technique using C#](https://gist.github.com/affix/994d7b806a6eaa605533f46e5c27fa5e)
- [PowerShell implementation of shellcode based Process Hollowing](https://gist.github.com/qtc-de/1ecc57264c8270f869614ddd12f2f276)

