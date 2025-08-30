# Microphone & Voice Commands Troubleshooting Guide

## Quick Checklist

### ✅ Browser Compatibility
- **Supported**: Chrome, Firefox, Edge, Safari (latest versions)
- **Not Supported**: Internet Explorer, very old browser versions

### ✅ Permission Setup

#### Chrome/Edge:
1. Click the 🔒 lock icon in the address bar
2. Set Microphone to "Allow"
3. Refresh the page
4. Test microphone in Audio Settings

#### Firefox:
1. Click the 🛡️ shield icon in the address bar
2. Allow microphone permissions  
3. Refresh the page
4. Test microphone in Audio Settings

#### Safari:
1. Go to Safari → Preferences → Websites
2. Select Microphone from the left sidebar
3. Set this website to "Allow"
4. Refresh the page

### ✅ Testing Process

1. **Go to Settings → Audio Settings**
2. **First: Click "Test Microphone"** (blue button)
   - This handles basic permission setup
   - Should see "Microphone Working!" message
3. **Then: Click "Test Voice Commands"** 
   - **First attempt**: Browser may ask for permission - click "Allow"
   - **Subsequent attempts**: Should work immediately
   - Say "next" or "hello" when you see "Listening..."
4. **If first voice test fails**: Click "Try Again" - should work on second attempt

### ⚠️ Important Notes
- **First voice command test often fails** due to permission dialog
- **Always try at least twice** before troubleshooting
- **Permission dialog interrupts first attempt** - this is normal
- **After first success, subsequent tests should work immediately**

## Common Issues & Solutions

### Issue: "Test Microphone" shows permission error
**Solution**: 
- Make sure you clicked "Allow" when browser asked
- Check if another app is using your microphone
- Try refreshing the page and testing again

### Issue: "Test Voice Commands" always fails on first try
**Solution**: 
- This is normal! Browser permission dialog interrupts first attempt
- Click "Try Again" in the result dialog
- Second and subsequent attempts should work fine
- If still failing after 2-3 tries, check microphone permissions

### Issue: "No Command Heard" after first successful test
**Solution**:
- This was a previous bug - should be fixed now
- Voice service now properly resets between tests
- Each test should work independently
- If still occurring, try refreshing the page
**Solution**:
- Check if microphone permission was previously denied
- In Chrome: Go to Settings → Privacy and security → Site Settings → Microphone
- Remove this site from "Blocked" list if present

### Issue: "No speech detected" error
**Solution**:
- Check if microphone is muted (hardware/software)
- Try speaking louder and closer to microphone
- Test microphone in other apps to verify it works
- Check Windows/Mac microphone privacy settings

### Issue: Voice commands don't work in lessons
**Solution**:
1. First ensure "Test Microphone" works in Audio Settings
2. In lessons, click the 🎙️ hands-free mode button
3. Wait for "listening" indicator before speaking
4. Say "next" clearly when the indicator shows listening

## Debugging Commands

### Browser Console (F12)
Look for these messages to understand what's happening:

```
🎙️ Voice state changed: VoiceInputState.listening  // Good - listening started
🎙️ Voice state changed: VoiceInputState.error      // Bad - permission/error
Speech status: listening                            // Good - browser is listening
Speech status: notListening                         // Normal - finished listening
```

### Test Commands
- **"next"** - Move to next content
- **"previous"** - Move to previous content  
- **"repeat"** - Repeat current content
- **"pause"** - Pause lesson

## Hardware Checklist

- [ ] Microphone is connected and working
- [ ] Microphone is not muted in system settings
- [ ] No other apps are using the microphone
- [ ] Browser has microphone permission
- [ ] Website has microphone permission

## Still Having Issues?

1. **Try a different browser** (Chrome recommended)
2. **Check system microphone privacy settings**
3. **Test with headphones/external microphone**
4. **Clear browser cache and cookies for this site**
5. **Restart browser completely**

## Browser-Specific Notes

### Chrome
- Most reliable for speech recognition
- Shows clear permission prompts
- Good error messages

### Firefox  
- Generally works well
- May need manual permission setup
- Check shield icon in address bar

### Safari
- Works on newer versions
- May require manual setup in Preferences
- Less detailed error messages

### Mobile Browsers
- Support varies by device
- May require different permission setup
- Touch and hold the microphone button may help
