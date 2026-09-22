---
title: "用 Hugo 搭建这个网站"
date: 2026-09-21T10:00:00+08:00
draft: false
description: "简单记录这个个人网站使用的工具和发布方式。"
tags: ["Hugo", "GitHub Pages"]
categories: ["技术"]
---

这个网站由 [Hugo](https://gohugo.io/) 生成，并采用简洁的 [PaperMod](https://github.com/adityatelange/hugo-PaperMod) 主题。

## 网站结构

- 使用 Markdown 编写文章
- 使用 Git 管理版本
- 使用 GitHub Actions 自动构建
- 使用 GitHub Pages 免费发布

每次向主分支推送新的文章后，GitHub Actions 都会重新构建并发布站点，因此日常更新只需要专注于写作。

```bash
hugo new content posts/my-new-post.md
hugo server -D
```

这篇文章也是占位内容，之后可以直接修改或删除。
