# 실험실 iOS

[jaehyeon_portfolio](https://github.com/LimJaeHyeon9298/jaehyeon_portfolio) 실험실(/lab)의 앱 실험들.
브라우저에서 돌릴 수 없는 실험을 여기서 만들고, 녹화한 영상을 사이트에 올린다.

- 실험 하나 = `Lab/Experiments/` 의 화면 하나. `Lab/Experiment.swift` 에 등록한다.
- 실험 id 는 사이트 `src/data/lab.ts` 의 slug 와 같게 둔다.
- `-experiment <id>` 인자로 실행하면 그 실험 화면에서 바로 시작한다.

```sh
xcrun simctl launch booted com.jaehyeon.lab -experiment app-video-test
```
