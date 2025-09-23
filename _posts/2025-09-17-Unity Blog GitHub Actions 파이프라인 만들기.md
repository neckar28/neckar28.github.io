---
title: "Unity-Blog-GitHub Actions 파이프라인 만들기"
date: 2025-09-18
categories: "CI/CD"
tags: 프로그래밍 CI/CD 자동화
permalink: /posts/unity-blog-github-actions-pipeline
description: "Unity 프로젝트를 GitHub에 커밋하는 것만으로 WebGL 빌드를 만들어 블로그에 자동 업로드 하는 CI/CD 파이프라인 구축 가이드. GitHub Actions와 Jekyll을 활용한 DevOps 실습."
excerpt: "테크 PM 포지션 지원을 위해 Unity WebGL 빌드 자동화 파이프라인을 만들어보았습니다."
---

테크 PM 포지션에 지원해보기 위해 간단하게나마 Devops 경험이 필요하다고 생각해서, 간단한 CI/CD 파이프라인을 만들어보았다.

## 개요

### 목표

Unity WebGL 빌드를 github에 commit하는 것 만으로 블로그에 업로드 할 수 있게 한다. 

### 환경

- Unity3D 6000.0.41f1
- Jekyll, Minimal-Mistakes theme
- GitHub, GitHub Actions

### 구조

![image.png](\assets\images\Unity-Blog-GitHub Actions 파이프라인 만들기\image.png)

---

## GitHub Actions

[https://docs.github.com/ko/actions](https://docs.github.com/ko/actions)

### GitHub Actions 사용하기

- Repository의 .github/workflow/ 디렉토리에 정의 파일(yml)을 업로드 한다.
- workflow의 기본적인 속성들
    - name: workflow 이름
    - on: 트리거 조건
    - jobs: 실행할 작업의 집합

```yaml
#push 이벤트로 작동하는 트리거

on:
  push:
    branches: ["main"]
```

### Actions

[https://github.com/marketplace](https://github.com/marketplace)

GitHub Actions 마켓플레이스에 올라와 있는 공식/서드파티 액션들을 활용할 수 있다.

```yaml
# 워크플로우가 repository에 접근할 수 있게 하는 액션
# https://github.com/marketplace/actions/checkout

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
```

### 상태 확인

![image.png](\assets\images\Unity-Blog-GitHub Actions 파이프라인 만들기\image%201.png){: .center}

어떤 레포지토리의 Actions에 관련된 정보는 여기서 찾아볼 수 있다. 자세한 내용은 이것 저것 돌리다 보면 알게 된다.

---

## Unity 빌드하기

[https://game.ci/docs/](https://game.ci/docs/)

Unity 프로젝트를 Actions에서 빌드 하기 위해서 **game-ci**를 활용한다. game-ci는 Unity 프로젝트용 오픈소스 CI/CD 툴킷으로 빌드, 테스트, 배포가 가능하다.

과정은 다음과 같다.

1. GitHub 레포지토리를 준비한다.
    1. .gitignore 기본적인 정도로 정리하기
2. game-ci를 사용하기 위해 유니티 라이센스를 설정 한다.
3. Workflow를 정의한다.

### 유니티 라이센스 설정

Windows, Personal license 기준으로 다음과 같다.

1. Unity Hub 설치 및 로그인
2. 라이센스 활성화
3. C:\ProgramData\Unity\Unity_lic.ulf 파일 찾기, 없으면 라이센스 다시 활성화
4. GitHub → repository → Settings → Secrets and Variables → Actions에서 세 개의 키를 만든다.

![image.png](\assets\images\Unity-Blog-GitHub Actions 파이프라인 만들기\image%202.png){: .center}

![image.png](\assets\images\Unity-Blog-GitHub Actions 파이프라인 만들기\image%203.png){: width="230"}{: .center}

![image.png](\assets\images\Unity-Blog-GitHub Actions 파이프라인 만들기\image%204.png){: .center}

세 개의 키는 다음과 같다. 

1. UNITY_LICENSE: 찾아놓은 ulf 파일의 내용을 그대로 복사 붙여넣기 한다. 
2. UNITY_EMAIL: 유니티 계정 이메일
3. UNITY_PASSWORD: 유니티 계정 비밀번호

### 유니티 빌드 워크플로우

```yaml
#제목
name: Build WebGL

#트리거
on:
  push:
    branches: ["main"]

#작업들 정의
jobs:
  #작업 이름
  build:
    #작업들을 실행할 플랫폼
    runs-on: ubuntu-latest
    #작업 단계들
    steps:
      # 1. 체크아웃
      - uses: actions/checkout@v4
      
      # 2. 캐싱 (빌드 속도 향상)
      - name: Cache Library
        uses: actions/cache@v4
        with:
          path: Library
          key: Library-projectName-targetPlatform
          restore-keys: |
            Library-projectName-
            Library-

      # 3. 빌드
      - name: Unity-Builder (WebGL)
        uses: game-ci/unity-builder@v4
        env:
          {% raw %}UNITY_LICENSE: ${{ secrets.UNITY_LICENSE }}{% endraw %}
          {% raw %}UNITY_EMAIL: ${{ secrets.UNITY_EMAIL }}{% endraw %}
          {% raw %}UNITY_PASSWORD: ${{ secrets.UNITY_PASSWORD }}{% endraw %}
        with:
          targetPlatform: WebGL
```

빌드 된 프로그램은 임시 디스크에 저장되고, workflow가 끝나면 폐기된다. 

build/targetPlatform 디렉토리에 잠깐 저장된다. 이 예시에서는 build/WebGL 디렉토리.

### 결과

![image.png](\assets\images\Unity-Blog-GitHub Actions 파이프라인 만들기\image%205.png){: .center}

캐시 없이 빌드만 했을 때의 결과다.

---

## Unity 빌드를 블로그 Repository로 배포하기

블로그는 두 개의 브랜치로 관리 중이다. 

1. main: 블로그 소스 업로드
2. gh-pages: 블로그 빌드

따라서 빌드를 gh-pages의 특정 폴더에 예쁘게 올려놓는게 목표!

이 목표에 적합한 액션은 peaceiris/actions-gh-pages로, 세팅이 간단하고 pages에 잘 맞다. 

actions-gh-pages에서는 personal access token을 요구한다. 여기서는 기능을 세밀하게 제한 할 수 있는 Fine-grained personal access token (FPAT)를 사용한다. 

### Fine-grained personal access token 설정

- GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token

![image.png](\assets\images\Unity-Blog-GitHub Actions 파이프라인 만들기\image%206.png){: width="230"}{: .center}

![image.png](\assets\images\Unity-Blog-GitHub Actions 파이프라인 만들기\image%207.png){: width="230"}{: .center}

![image.png](\assets\images\Unity-Blog-GitHub Actions 파이프라인 만들기\image%208.png){: width="230"}{: .center}

![image.png](\assets\images\Unity-Blog-GitHub Actions 파이프라인 만들기\image%209.png){: .center}

- 토큰 설정
    1. Repository access를 블로그 레포지토리로 제한
    2. Permissions에 Contents, Read and write 추가

![image.png](\assets\images\Unity-Blog-GitHub Actions 파이프라인 만들기\image%2010.png){: .center}

- 토큰 복사 해 놓기. 한 번 밖에 못 본다.

![image.png](\assets\images\Unity-Blog-GitHub Actions 파이프라인 만들기\image%2011.png){: .center}

- 이 토큰을 유니티 라이센스 설정에서 본 것 처럼, 유니티 레포지토리의 secret 키로 만든다. 나는 BLOG_REPO_PAT로 설정했다. 

### 유니티 빌드 & 배포 워크플로우

```yaml
#제목
name: Build & Deploy WebGL

#트리거
on:
  push:
    branches: ["main"]

#작업들 정의
jobs:
  #작업 이름
  build:
    #작업들을 실행할 플랫폼
    runs-on: ubuntu-latest
    #작업 단계들
    steps:
      # 1. 체크아웃
      - uses: actions/checkout@v4
      
      # 2. 캐싱 (빌드 속도 향상)
      - name: Cache Library
        uses: actions/cache@v4
        with:
          path: Library
          key: Library-projectName-targetPlatform
          restore-keys: |
            Library-projectName-
            Library-

      # 3. 빌드
      - name: Unity-Builder (WebGL)
        uses: game-ci/unity-builder@v4
        env:
          {% raw %}UNITY_LICENSE: ${{ secrets.UNITY_LICENSE }}{% endraw %}
          {% raw %}UNITY_EMAIL: ${{ secrets.UNITY_EMAIL }}{% endraw %}
          {% raw %}UNITY_PASSWORD: ${{ secrets.UNITY_PASSWORD }}{% endraw %}
        with:
          targetPlatform: WebGL
          
      # 4. 배포
      - name: Deploy to Blog (gh-pages)
        uses: peaceiris/actions-gh-pages@v4
        with:
          {% raw %}personal_token: ${{ secrets.BLOG_REPO_PAT }}{% endraw %}
          # 배포할 레포지토리
          external_repository: neckar28/neckar28.github.io
          # 배포할 브랜치
          publish_branch: gh-pages
          # 배포할 빌드가 들어있는 디렉토리
          publish_dir: build/WebGL
          # 빌드를 넣을 디렉토리
          destination_dir: assets/webgl/pidgetcube
          # 기존 파일 유지
          keep_files: true
          # 기존 브랜치의 이력 유지
          force_orphan: false
          user_name: github-actions[bot]
          user_email: github-actions[bot]@users.noreply.github.com
```

### 결과

![image.png](\assets\images\Unity-Blog-GitHub Actions 파이프라인 만들기\image%2012.png){: .center}

빌드를 처음 했을 때는 20분 걸렸는데, 캐싱을 하니까 4분 5초까지 줄어들었다.

아래는 블로그 레포지토리에 commit된 WebGL 빌드!

![image.png](\assets\images\Unity-Blog-GitHub Actions 파이프라인 만들기\image%2013.png){: .center}

---

## 블로그 빌드/배포 방법 정돈

기존에는 로컬에서 블로그를 빌드하고 gh-pages 브랜치에 올리고 있었다. 그런데 Actions로 배포된 게임은 로컬에 없기 때문에 

1. 매번 fetch를 하거나, 
2. actions를 이용해서 빌드/배포 과정을 거쳐야 한다. 

그런데 1번 방법은 직접 fetch하는 **과정이 추가**되고, 2번 방법은 직접 build/deploy하는 **과정이 생략**된다. 그래서 2번 방법을 쓰기로 했다.

### 블로그 빌드 & 배포 워크플로우

```yaml
name: Build & Deploy Blog

# main에 push되면 시작
on:
  push:
    branches: ["main"]

permissions:
  contents: write

jobs:
  build-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      # Ruby 설치 (Jekyll)
      - uses: actions/setup-ruby@v1
        with:
          ruby-version: 3.4.5
      # Jekyll 빌드 (_site 디렉토리에 저장)
      - run: bundle install
      - run: bundle exec jekyll build -d _site

      # gh-pages 브랜치로 배포
      - name: Deploy to gh-pages
        uses: peaceiris/actions-gh-pages@v4
        with:
          # 같은 레포 내부에서는 github_token으로 (설정 필요하지 않음)
          {% raw %}github_token: ${{ secrets.GITHUB_TOKEN }}{% endraw %}
          publish_dir: ./_site
          publish_branch: gh-pages
          keep_files: true
          force_orphan: false
```

## 결과

<iframe
  src="/assets/webgl/pidgetcube/WebGL/index.html"
  style="width:100%; height:720px; border:0;"
  loading="lazy"
  allowfullscreen
></iframe>

## 다음 포스트

[GitHub Actions에 Unity Test Runner 올리기](https://neckar28.github.io/posts/unity-test-runner-on-github-acitons)