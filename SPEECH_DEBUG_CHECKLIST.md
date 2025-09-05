# Speech Recognition Debug Checklist

## Current Issue
- Speech recognition starts successfully (`isListening: true`)
- No sound level detection logs appearing
- Speech recognition immediately transitions to `done` state
- No actual speech detection despite talking

## Enhanced Logging Added
✅ More detailed sound level logging (now logs ALL levels, not just > 0.01)
✅ Enhanced speech result processing with type information
✅ Status change tracking in initialization
✅ Additional debug info about speech service state
✅ Longer pause time (3 seconds instead of 1)
✅ Enabled partial results and disabled cancel on error

## Tests to Perform

### 1. Basic Sound Level Test
- Look for `🎙️ Sound level:` messages in console
- Should appear continuously while listening
- Values should change when speaking vs. silent

### 2. Microphone Access Test
- Check Chrome microphone permissions in browser settings
- Look for microphone icon in address bar when listening
- Verify no other apps are using microphone

### 3. Speech Recognition Configuration Test
- Check available locales: `🎙️ Debug - Speech locales available:`
- Verify language setting (en_US vs en-US)
- Test different speech clarity and volume levels

### 4. Browser Compatibility Test
- Verify Chrome version supports Web Speech API
- Check for any console errors during recognition
- Test in incognito mode to rule out extension conflicts

## Expected Behavior
1. Start listening → `🎙️ Native provider start listening completed, isListening: true`
2. Sound detection → `🎙️ Sound level: [value]` (continuous stream)
3. Speech recognition → `🎙️ Speech result received: "[words]"`
4. Completion → Final result or timeout

## Common Issues & Solutions
- **No sound levels**: Microphone not accessible or permission issue
- **Sound but no recognition**: Language/locale mismatch or unclear speech
- **Immediate timeout**: Configuration error or API limitation
- **Permission denied**: Browser security settings or HTTPS requirement

## Browser Requirements
- HTTPS connection (✅ localhost counts)
- Microphone permissions granted (✅ confirmed)
- Chrome/Edge browser (✅ using Chrome)
- No conflicting audio applications

## Next Steps
1. Test with enhanced logging
2. Check sound level detection
3. Verify microphone access indicator
4. Test with clear, simple words like "hello"
5. Try different speech patterns and volumes
