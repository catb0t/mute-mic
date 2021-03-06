# mute-mic 2021-02-21 @ 19:34
# https://stackoverflow.com/a/27992426/4532996
$t = '[DllImport("user32.dll")] public static extern bool ShowWindow(int handle, int state);'
add-type -name win -member $t -namespace native
[native.win]::ShowWindow(([System.Diagnostics.Process]::GetCurrentProcess() | Get-Process).MainWindowHandle, 0)

$process = "powershell.exe"
$cmdlines = (Get-WmiObject Win32_Process -Filter "name = '$process'" | Select-Object CommandLine | Where-Object {$_.CommandLine.Contains('mute-mic.ps1')} )
if ($cmdlines.count -gt 0) {
  Write-Host "Process already exists, never mind"
  exit
}

Import-Module -Name "$((Get-Item .).FullName)\AudioDeviceCmdlets"

function Show-Notification {
    # https://den.dev/blog/powershell-windows-notification/
    [cmdletbinding()]
    Param (
        [string]
        $ToastTitle,
        [string]
        [parameter(ValueFromPipeline)]
        $ToastText
    )

    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
    $Template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)

    $RawXml = [xml] $Template.GetXml()
    ($RawXml.toast.visual.binding.text|where {$_.id -eq "1"}).AppendChild($RawXml.CreateTextNode($ToastTitle)) > $null
    ($RawXml.toast.visual.binding.text|where {$_.id -eq "2"}).AppendChild($RawXml.CreateTextNode($ToastText)) > $null

    $SerializedXml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $SerializedXml.LoadXml($RawXml.OuterXml)

    $Toast = [Windows.UI.Notifications.ToastNotification]::new($SerializedXml)
    $Toast.Tag = "MutingService"
    $Toast.Group = "MutingService"
    $Toast.ExpirationTime = [DateTimeOffset]::Now.AddMinutes(2)

    $Notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Muting Service")
    $Notifier.Show($Toast);
}

# Show-Notification "Starting up ..." "Compiling .NET interop ..."

# https://stackoverflow.com/a/54237188/4532996
Add-Type -TypeDefinition '
using System;
using System.IO;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace KeyLogger {
  public static class Program {
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;

    private static HookProc hookProc = HookCallback;
    private static IntPtr hookId = IntPtr.Zero;
    private static int keyCode = 0;

    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll")]
    private static extern IntPtr SetWindowsHookEx(int idHook, HookProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("kernel32.dll")]
    private static extern IntPtr GetModuleHandle(string lpModuleName);

    public static int WaitForKey() {
      hookId = SetHook(hookProc);
      Application.Run();
      UnhookWindowsHookEx(hookId);
      return keyCode;
    }

    private static IntPtr SetHook(HookProc hookProc) {
      IntPtr moduleHandle = GetModuleHandle(Process.GetCurrentProcess().MainModule.ModuleName);
      return SetWindowsHookEx(WH_KEYBOARD_LL, hookProc, moduleHandle, 0);
    }

    private delegate IntPtr HookProc(int nCode, IntPtr wParam, IntPtr lParam);

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
      if (nCode >= 0 && wParam == (IntPtr)WM_KEYDOWN) {
        keyCode = Marshal.ReadInt32(lParam);
        Application.Exit();
      }
      return CallNextHookEx(hookId, nCode, wParam, lParam);
    }
  }
}
' -ReferencedAssemblies System.Windows.Forms

function Get-MutingState {
  $state = $false
  If (Get-AudioDevice -RecordingMute) {
    $state = @('Muting', 'disabled')
  } Else {
    $state = @('Unmuting', 'enabled')
  }
  return $state
}

function Do-ToggleMute {
  Set-AudioDevice -RecordingMuteToggle
  $state = Get-MutingState
  Show-Notification $state[0] "Microphone $($state[1])"
}

function Loop-WaitForShortcut {
  $mute_key = "Divide"
  $stop_keys = @("RControlKey", "Insert")
  $state = Get-MutingState
  Show-Notification "Started in state: $($state[0])" "Microphone $($state[1])`nToggle with <$mute_key>`nStop with <$($stop_keys[0])+$($stop_keys[1])>"
  $lastkey1 = $false
  # $lastkey2 = $false
  while ($true) {
      $key = [System.Windows.Forms.Keys][KeyLogger.Program]::WaitForKey()
      Write-Host $key
      if ($key -eq $mute_key) {
          Do-ToggleMute
          Write-Host "Muting toggled"
      } elseif (-not (Compare-Object @($lastkey1, $key) $stop_keys)) {
          Show-Notification "Service stopped" "Restart with <Ctrl+Shift+Divide>"
          exit
      }
      # $lastkey2 = $lastkey1
      $lastkey1 = $key
  }
}

Loop-WaitForShortcut
