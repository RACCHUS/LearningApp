# Hands-Free Testing Guide

## How to Test the Hands-Free Implementation

### 1. Access the Test Screen
- Open the app and look for the brain icon (🧠) in the top-right of the home screen
- Click it to navigate to `/test/hands-free`
- This opens the comprehensive hands-free testing interface

### 2. Test Voice Command Recognition

#### Enable Microphone
1. Click "Start Listening" button
2. Allow microphone permissions when prompted
3. Watch for the "Listening..." indicator

#### Test Basic Commands
Try saying these commands clearly:

**Lesson Control Commands:**
- "play lesson" or "start lesson"
- "pause lesson" or "stop lesson"  
- "resume lesson" or "continue lesson"
- "next page" or "go to next"
- "previous page" or "go back"
- "repeat page" or "repeat this"
- "go to page 5" (replace 5 with any number)
- "what page" or "current page"
- "how many pages" or "total pages"
- "lesson progress" or "my progress"
- "help" or "what can I say"
- "lesson complete" or "finish lesson"

**Global Navigation Commands:**
- "go to home" or "home page"
- "go to settings" or "open settings"
- "go to profile" or "my profile"
- "go to lessons" or "lesson list"
- "create lesson" or "new lesson"
- "open lesson laptop basics" (replace with actual lesson name)

### 3. Test Settings Persistence

#### Enable Default Hands-Free Mode
1. Go to Settings → Audio Settings
2. Enable "Default Hands-Free Mode"
3. Restart the app
4. Verify hands-free mode auto-starts

#### Test Voice Preferences
1. Adjust voice settings (speed, pitch, language)
2. Test text-to-speech with different settings
3. Verify settings persist across sessions

### 4. Test UI Indicators

#### Global Voice Indicator
- Look for the microphone icon in the app bar
- Should show listening state (blue when active)
- Click to toggle hands-free mode on/off

#### Hands-Free FAB
- Floating action button appears when hands-free mode is enabled
- Shows current status (listening/idle)
- Provides quick access to help

### 5. Validate Integration

#### Voice Command Parsing
- Test in the test screen's "Test Command" section
- Type commands to see how they're parsed
- Verify correct command type detection

#### Error Handling
- Try unclear speech or background noise
- Verify graceful error handling
- Check timeout behavior

#### Context Awareness
- Test commands in different app contexts
- Verify appropriate responses
- Check help text adapts to current screen

## Expected Behavior

### Working Features ✅
- Voice command recognition and parsing
- Settings persistence with SharedPreferences
- UI indicators and controls
- Comprehensive test interface
- Error handling and timeouts

### In Progress 🚧
- Full app navigation integration
- Lesson-specific voice controls in actual lessons
- Onboarding flow for new users

## Troubleshooting

### Common Issues
1. **Microphone not working**: Check browser permissions
2. **Commands not recognized**: Speak clearly, reduce background noise
3. **Settings not saving**: Check browser storage permissions
4. **App crashes**: Check console for errors, restart if needed

### Debug Information
- The test screen shows real-time status
- Console logs provide detailed debugging info
- Voice recognition status is displayed continuously

## Next Steps

After testing the current implementation:
1. Complete Phase 4 integration (connect navigation commands to actual routing)
2. Add voice controls to lesson screens
3. Implement onboarding flow for first-time users
4. Polish UI/UX based on testing feedback
