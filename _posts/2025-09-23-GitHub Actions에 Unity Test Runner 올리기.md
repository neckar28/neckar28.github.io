---
title: "GitHub Actions에 Unity Test Runner 올리기"
date: 2025-09-23
categories: "CI/CD"
tags: 프로그래밍 CI/CD 자동화
permalink: /posts/unity-test-runner-on-github-acitons
description: "Unity 프로젝트에 GitHub Actions를 활용한 자동화된 테스트 환경을 구축하는 과정을 다룹니다. Unity Test Framework 설정부터 CI/CD 파이프라인에서의 테스트 자동화까지, 실제 구현 과정에서 마주친 문제들과 해결방법을 공유합니다."
excerpt: "Unity 프로젝트의 CI/CD 파이프라인에 Test Runner를 통합하여 자동화된 테스트 환경을 구축했습니다. dev 브랜치에서는 테스트만, main 브랜치에서는 테스트부터 배포까지 이어지는 완전한 자동화 워크플로우를 만들었습니다."
---

[지난 포스트](https://neckar28.github.io/posts/unity-blog-github-actions-pipeline)의 연장선으로, CI 과정의 테스트 자동화를 학습하기 위해 GitHub Actions에 Unity test runner를 올려보았다. 

## 브랜치 구분하기

Unity repository에서, 기존에는 main 브랜치에 push하면 바로 빌드와 배포가 진행되었다. 그러나 자동 test와, 빌드, 배포를 구분하기 위해서, 개발 브랜치와 배포 브랜치를 구분해야 했다. 따라서 dev 브랜치를 하나 추가하였다.

![image.png](\assets\images\GitHub Actions에 Unity Test Runner 올리기\image.png){: .center}

---

## Unity 테스트 만들기

- Unity Package Manager에서 Test Framework를 인스톨
- Assembly definition (asmdef) 생성
    - 작은 게임 환경이라서 Runtime, EditMode, PlayMode로 구분했다.
- 테스트 코드 작성
- 테스트 실행

Assembly definition을 만드는 이유는 게임 빌드에 테스트가 들어가지 않도록 하기 위함이다.

Edit mode는 게임 실행이나 시간 흐름이 불필요한, 단순한 속성이나 계산 로직을 검증하는데 사용한다. 반면 Play mode는 Physics, Animation, MonoBehaviour 생명주기 테스트, Scene 로드 등, 테스트에 실제 시간이 흘러야하는 검증에 사용한다. 

두 모드를 나누기 위해서는 플랫폼 설정이 필요하다.

![image.png](\assets\images\GitHub Actions에 Unity Test Runner 올리기\image%201.png){: width="230"}{: .center}

Edit mode 플랫폼 설정

![image.png](\assets\images\GitHub Actions에 Unity Test Runner 올리기\image%202.png){: width="230"}{: .center}

Play mode 플랫폼 설정

## 결과

![image.png](\assets\images\GitHub Actions에 Unity Test Runner 올리기\image%203.png){: .center}

### 트러블 슈팅

asmdef 생성 후 URP 네임스페이스 (UnityEngine.Rendering.Universal)와 Volume 등을 인식하지 못하는 문제가 발생 했다. asmdef의 Assembly Definition References 속성에 Unity.RenderPipelines.Universal.Runtime, Unity.RenderPipelines.Core.Runtime 추가하여 네임스페이스를 참조할 수 있도록 했다.

![image.png](\assets\images\GitHub Actions에 Unity Test Runner 올리기\image%204.png){: .center}

---

## GitHub Actions 테스트 workflow 추가

테스트를 위해서 기존에 사용하던 game-ci의 unity-test-runner를 활용하였다.

```yaml
name: Test

on:
  push:
    branches: ["dev"]

# 작동중인 같은 작업이 있으면 중단
concurrency:
  {% raw %}group: unity-tests-${{ github.ref }}{% endraw %}
  cancel-in-progress: true

# 권한 부여
permissions:
  contents: read
  checks: write

jobs:
  tests:
      name: Run tests
      runs-on: ubuntu-latest
      timeout-minutes: 30

      env:
          {% raw %}UNITY_LICENSE: ${{ secrets.UNITY_LICENSE }}{% endraw %}
          {% raw %}UNITY_EMAIL: ${{ secrets.UNITY_EMAIL }}{% endraw %}
          {% raw %}UNITY_PASSWORD: ${{ secrets.UNITY_PASSWORD }}{% endraw %}
      
      steps:
        - name: Checkout
          uses: actions/checkout@v4

        - name: Unity tests
          uses: game-ci/unity-test-runner@v4
          with:
            {% raw %}githubToken: ${{ secrets.GITHUB_TOKEN }}{% endraw %}
            unityVersion: 6000.0.41f1
            projectPath: .
            customParameters: '-nographics'
```

### 트러블 슈팅 1

![image.png](\assets\images\GitHub Actions에 Unity Test Runner 올리기\image%205.png){: .center}

githubToken: ${{ secrets.GITHUB_TOKEN }} 을 제공할 경우 game-ci가 github의 상태검사에 체크 메시지를 남긴다. 하지만 checks에 쓰기 권한이 없어서 생기는 에러. 따라서 permissions에 checks: write로 권한을 주었다.

![image.png](\assets\images\GitHub Actions에 Unity Test Runner 올리기\image%206.png){: width="300"}{: .center}

![image.png](\assets\images\GitHub Actions에 Unity Test Runner 올리기\image%207.png){: .center}

### 트러블 슈팅 2

![image.png](\assets\images\GitHub Actions에 Unity Test Runner 올리기\image%208.png){: .center}

![image.png](\assets\images\GitHub Actions에 Unity Test Runner 올리기\image%209.png){: .center}

Exit code 139 오류가 생겼다. game-ci 이슈 페이지에서 비슷한 문제를 발견해서, customParameters: '-nographics' 속성을 추가하였다. 

[https://github.com/game-ci/unity-test-runner/issues/68](https://github.com/game-ci/unity-test-runner/issues/68)

이슈에서 나오는 증상과 달리, Burst와 Code Coverage가 맞물리는 segmentation fault라서, 지속적으로 문제가 생길 경우 추가적인 조치를 할 예정이다.

---

## 결론

![image.png](\assets\images\GitHub Actions에 Unity Test Runner 올리기\image%2010.png){: .center}

dev에 commit할 경우 테스트, main에 merge할 경우 테스트, 빌드, 배포까지 이어지는  CI/CD 흐름을 만들었다.

그리고 빌드에는 요금이 나온다.

![image.png](\assets\images\GitHub Actions에 Unity Test Runner 올리기\image%2011.png){: .center}