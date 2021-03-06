#SingleInstance Force

ShowNotification(title, text)
{
  notif_option := 0x24 | 32
  TrayTip(text, title, notif_option)
}

/* if we're toggling more than one object at the same time, we need to set them
  all to a known-same known-safe state before we can toggle them
  because they could start in relatively opposite states and toggling them
  all would not result in a known configuration
*/
InitMuteAll()
{
  try
  {
    SoundSetMute(true, "", "Microphone")
    SoundSetMute(true, "Microphone")
    SoundSetMute(true, "Line in")
  }
}

SetMuteAll(state)
{
  try
  {
    if SoundGetMute("", "Microphone") == state
    {
      SoundSetMute(!state, "", "Microphone")
    }
    if SoundGetMute("Microphone") == state
    {
      SoundSetMute(!state, "Microphone")
    }
    if SoundGetMute("Line in") == state
    {
      SoundSetMute(!state, "Line in")
    }
  }
}

ico_off := (57*4) + 2
ico_on := (58*4) + 1
TraySetIcon("imageres.dll", ico_off)

InitMuteAll()
ShowNotification("Muting Service Started", "Now Muting")
state := true
F12::
{
  global state
  global ico_on
  global ico_off
  SetMuteAll(state)
  TraySetIcon("imageres.dll", (state ? ico_on : ico_off))
  ShowNotification((state ? "Unmuting" : "Muting"), ("Microphone " . (state ? "enabled" : "disabled")))
  global state := !state
}
