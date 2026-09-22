<#
.SYNOPSIS
    验证、提交并发布 Hugo 博客。

.EXAMPLE
    .\publish.ps1

.EXAMPLE
    .\publish.ps1 -Message "新增一篇学习笔记"

.EXAMPLE
    .\publish.ps1 -SkipBuild -Message "修正文案"
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Message,

    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Git {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    & git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Git 命令执行失败：git $($Arguments -join ' ')"
    }
}

function Find-HugoExecutable {
    $command = Get-Command hugo -CommandType Application -ErrorAction SilentlyContinue
    if (-not $command) {
        throw '没有找到 Hugo。请先安装 Hugo Extended，并确保 hugo 命令位于 PATH 中。'
    }

    # WinGet 创建的 hugo.exe 可能是符号链接；优先使用它指向的真实文件。
    $commandItem = Get-Item -LiteralPath $command.Source
    if ($commandItem.LinkType -and $commandItem.Target) {
        $target = [string]$commandItem.Target
        if (Test-Path -LiteralPath $target -PathType Leaf) {
            return $target
        }
    }

    return $command.Source
}

$repoRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($repoRoot)) {
    $repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

Push-Location -LiteralPath $repoRoot

try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw '没有找到 Git。请先安装 Git，并确保 git 命令位于 PATH 中。'
    }

    & git rev-parse --is-inside-work-tree 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "当前目录不是 Git 仓库：$repoRoot"
    }

    $branch = (& git branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw '无法读取当前 Git 分支。'
    }
    if ($branch -ne 'main') {
        throw "当前分支是 '$branch'，请切换到 main 后再发布。"
    }

    if (-not $SkipBuild) {
        Write-Host '1/4 正在验证 Hugo 构建……' -ForegroundColor Cyan
        $hugo = Find-HugoExecutable
        & $hugo --gc --minify
        if ($LASTEXITCODE -ne 0) {
            throw 'Hugo 构建失败，已停止提交。请先修复上面的错误。'
        }
        Write-Host 'Hugo 构建成功。' -ForegroundColor Green
    }
    else {
        Write-Host '1/4 已跳过 Hugo 构建。' -ForegroundColor Yellow
    }

    Write-Host '2/4 正在整理本次改动……' -ForegroundColor Cyan
    Invoke-Git -Arguments @('add', '--all')

    & git diff --cached --quiet
    $diffExitCode = $LASTEXITCODE
    if ($diffExitCode -eq 0) {
        Write-Host '没有需要提交的改动。' -ForegroundColor Yellow
        exit 0
    }
    if ($diffExitCode -ne 1) {
        throw '无法检查待提交的改动。'
    }

    Write-Host ''
    Invoke-Git -Arguments @('status', '--short')
    Write-Host ''

    if ([string]::IsNullOrWhiteSpace($Message)) {
        $Message = Read-Host '请输入提交说明（直接回车将使用当前时间）'
    }
    if ([string]::IsNullOrWhiteSpace($Message)) {
        $Message = "更新博客 $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    }

    Write-Host "3/4 正在提交：$Message" -ForegroundColor Cyan
    Invoke-Git -Arguments @('commit', '-m', $Message)

    Write-Host '正在同步远程 main 分支……' -ForegroundColor Cyan
    try {
        Invoke-Git -Arguments @('pull', '--rebase', 'origin', 'main')
    }
    catch {
        Write-Host '同步失败。如果出现冲突，请解决冲突后执行 git rebase --continue，再重新运行本脚本。' -ForegroundColor Red
        throw
    }

    Write-Host '4/4 正在推送到 GitHub……' -ForegroundColor Cyan
    Invoke-Git -Arguments @('push', 'origin', 'main')

    Write-Host ''
    Write-Host '发布完成！GitHub Actions 将自动更新网站：' -ForegroundColor Green
    Write-Host 'https://mako-0831.github.io/' -ForegroundColor Green
}
catch {
    Write-Host ''
    Write-Host "发布失败：$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Pop-Location
}
