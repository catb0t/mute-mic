; IAudioMeterInformation
audioMeter := SoundGetInterface("{C02216F6-8C67-4B5B-9D00-D008E73E0064}")
if audioMeter
{
    try loop  ; Until the script exits or an error occurs.
    {
        ; audioMeter->GetPeakValue(&peak)
        ComCall 3, audioMeter, "float*", peak:=0
        peak := Round(peak * 100)
        ToolTip peak > 0 ? peak : ""
        Sleep 15
    }
    ObjRelease audioMeter
}
else
    MsgBox "Unable to get audio meter"
