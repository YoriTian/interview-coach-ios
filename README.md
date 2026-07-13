# Interview Coach iOS

Interview Coach iOS is a SwiftUI app for Chinese interview preparation. It combines a local question bank, resume parsing, JD-based question matching, speech input, AI scoring, answer coaching, recitation practice, mock interview reports, wrong-question review, and spaced repetition.

This repository is privacy-sanitized. It does not include personal resumes, real candidate data, device identifiers, Apple account information, provisioning profiles, or API keys.

## Features

- Resume parsing from PDF or text
- Technical stack extraction for topics such as Jenkins, CI/CD, Docker, Kubernetes, Harbor, Helm, Linux, Prometheus, and Grafana
- JD-based training: paste a job description and generate targeted practice
- Multiple practice modes: resume follow-up, JD training, technical drills, project review, delivery scenarios, product manager, implementation engineer, wrong questions, daily drill, review plan, and flashcards
- Speech input with Mandarin speech recognition
- DeepSeek V4 Pro deep-thinking mode for AI scoring and coaching
- AI-generated technical interview questions based only on extracted resume tech stacks
- Target-answer generation, answer framework, key phrases, and recitation scoring
- Mock interview session reports with weak-point summary and next actions
- Spaced repetition and wrong-question tracking
- Local-first storage with Keychain for API keys and UserDefaults for learning progress, resume profiles, and generated questions

## Privacy And Secrets

- No API key is committed in this repository.
- Users enter their own DeepSeek API key inside the app. The key is stored in the local iOS Keychain.
- Do not hard-code API keys in `Info.plist`, source files, screenshots, or test fixtures.
- The bundled `questions.json` and `resume_profile.json` are anonymous starter data, not a real resume.
- Before publishing a fork, run a secret scan and remove `xcuserdata`, provisioning profiles, derived data, logs, archives, and local config files.

## Requirements

- iOS 17.0+
- Xcode 26+
- Swift 6.0

## Getting Started

1. Open `InterviewCoach.xcodeproj` in Xcode.
2. Select the `InterviewCoach` target.
3. Set your own Apple Development Team.
4. Change the bundle identifier from `com.example.interviewcoach` to one you control if you want to run on a real device.
5. Build and run.
6. In the app settings, enter your own DeepSeek API key if you want AI scoring and coaching.

Simulator build without signing:

```bash
xcodebuild \
  -project InterviewCoach.xcodeproj \
  -scheme InterviewCoach \
  -configuration Debug \
  -sdk iphonesimulator \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Run tests:

```bash
xcodebuild \
  -project InterviewCoach.xcodeproj \
  -scheme InterviewCoach \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

## Project Structure

```text
InterviewCoach/
  Models/          Core data models
  Services/        AI, resume parsing, question matching, speech, review storage
  ViewModels/      App state and training workflow
  Views/           SwiftUI screens and components
  Resources/       Anonymous starter question bank and app assets
InterviewCoachTests/
  Unit tests
```

## License

MIT License. See `LICENSE`.
