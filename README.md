# 📦 Peeker

**Peeker**는 iOS 앱에서 실시간으로 메모리 사용량을 시각화할 수 있는 가벼운 개발용 도구입니다.  
디버깅 또는 성능 튜닝 과정에서 앱의 메모리 소비 상태를 직관적으로 확인할 수 있도록 돕습니다.

<img src="https://github.com/user-attachments/assets/fbb0076a-d19f-4ef2-b3a8-9bc99a7fe465" width="200" height="400"/>

---

## ✨ Features

- 실시간 메모리 사용량 모니터링 (App Heap + Physical Memory)
- 화면 상단에 메모리 사용량을 그래프로 표시
- SPM / CocoaPods 지원
- Debug 모드에서만 동작 (옵션)

---

## 📦 Installation

### Swift Package Manager

```swift
.package(url: "https://github.com/doitduri/Peeker.git", from: "1.0.0")
```
또는 Xcode → File → Add Package → URL 입력

### CocoaPods
```ruby
pod 'Peeker'
```

### 🚀 Usage
#### 1. Import
```swift
import Peeker
```

#### 2. Start Monitoring
앱 실행 시 한 번만 호출하면 됩니다.
```swift
Peeker.start()
````

옵션을 커스터마이즈하고 싶다면:
```swift
Peeker.start(
    interval: 1.0, // update every second
    showInRelease: false // only show in Debug builds
)
```

### 🧪 Example
예제 프로젝트는 `Example/PeekerExample` 디렉토리에 포함되어 있습니다.

Xcode로 열어 직접 확인해 보세요.

### 📄 License
MIT License.
Copyright (c) 2025 doitduri
