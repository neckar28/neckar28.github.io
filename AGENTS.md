# AGENTS

Guidelines for anyone (human or AI) helping maintain this blog repository.

## Quick facts
- Site: Jekyll-based blog.
- Content lives in `_posts/` (dated filenames, YAML front matter required) and `_pages/`.
- Shared snippets live in `_includes/`; layouts in `_layouts/`; data in `_data/`.
- Assets (images, JS, CSS) live under `assets/`.

## Local setup
- Prereq: Ruby + Bundler installed.
- Install deps: `bundle install`.
- Run locally: `bundle exec jekyll serve`.
- Build check: `bundle exec jekyll build`.

## Editing rules
- Keep front matter tidy: `title`, `date`, `layout`, and `tags` as needed.
- Favor ASCII; only use Unicode when already present or required for content.
- Add concise comments only when code/config is non-obvious.
- Do not rewrite or remove user changes you did not author.
- Avoid destructive git commands (`git reset --hard`, force pushes, etc.).

## Content notes
- Posts: place in `_posts/YYYY-MM-DD-title.md`; include summary-friendly intro.
- Pages: add to `_pages/` with appropriate layout reference.
- Assets: use relative paths; prefer optimized images (compress before commit).
- SEO helpers: ensure meaningful `title` and, when applicable, `description`.

## Before you open a PR
- `bundle exec jekyll build` succeeds locally.
- Check for broken links or missing assets in new content.
- Proofread for typos; keep formatting consistent with existing posts.
- If touching configs, note rationale in the PR description.

## If you are an AI agent
- Be explicit about file paths you change.
- When unsure about content or style, ask for clarification before large edits.
- Prefer minimal diffs; avoid large refactors unless requested.
