param([string]$RepoUrl = "https://github.com/xDzLeozzz/hecate-nautilus.git")

$ErrorActionPreference = "Stop"
function Say([string]$m){ Write-Host "`n=== $m ===" -ForegroundColor Cyan }
function TryRun([scriptblock]$b){ try{ & $b 2>&1 } catch { $_ | Out-String } }

# Detecta docker compose (não é essencial pro git, mas útil em geral)
$DC = "docker compose"
if (Get-Command docker-compose -ErrorAction SilentlyContinue) { $DC = "docker-compose" }

# ------------- Verificação/Inicialização do Git -------------
Say "Checando repositório Git"
$inRepo = $false
try { $inRepo = (git rev-parse --is-inside-work-tree) -eq "true" } catch {}
if(-not $inRepo){
  Say "Não é repo ainda — inicializando"
  git init
  git branch -M main
  if(-not (git remote 2>$null | Select-String -Quiet "^origin$")){ git remote add origin $RepoUrl }
} else {
  if(-not (git remote 2>$null | Select-String -Quiet "^origin$")){ git remote add origin $RepoUrl }
}

# Confere/ajusta URL do origin
$curUrl = TryRun { git remote get-url origin }
if($curUrl -is [string] -and $curUrl.Trim() -ne $RepoUrl){
  Say "Atualizando origin: $curUrl -> $RepoUrl"
  git remote set-url origin $RepoUrl
}

# ------------- Arquivos de controle (gitattributes / gitignore) -------------
Say "Atualizando .gitattributes (EOL correto)"
$ga = @"
*.sh   text eol=lf
*.bash text eol=lf
*.yml  text eol=lf
*.yaml text eol=lf
*.conf text eol=lf
*.txt  text eol=lf
*.ps1  text eol=crlf
"@
$ga | Out-File -Encoding ascii -LiteralPath .gitattributes

Say "Atualizando .gitignore (ignorar backups, tar, logs...)"
$giDesired = @"
# Backups e artefatos
backups/
*.tar
*.tgz
*.log

# Volumes/estado de runtime
**/unbound_etc/**
**/.DS_Store
"@
# Mescla/garante linhas (sem duplicar)
$giPath = ".gitignore"
$existing = @()
if(Test-Path $giPath){ $existing = Get-Content -LiteralPath $giPath -ErrorAction SilentlyContinue }
$toAdd = @()
foreach($line in ($giDesired -split "`n")){
  $l = $line.TrimEnd("`r")
  if($l -ne "" -and ($existing -notcontains $l)){ $toAdd += $l }
}
if($toAdd.Count -gt 0){ Add-Content -Encoding ascii -LiteralPath $giPath -Value ($toAdd -join "`r`n") }

# ------------- Normalizar EOL dos arquivos críticos -------------
Say "Normalizando EOL (LF para *.sh/*.yml/*.conf)"
$paths = @(
  "unbound/entrypoint.sh",
  "unbound/config/unbound.conf",
  "unbound/config/root.hints",
  "docker-compose.yml",
  "docker-compose.override.yml",
  "compose.unbound.windows.yml"
) | Where-Object { Test-Path $_ }
foreach($p in $paths){
  (Get-Content -Raw $p) -replace "`r`n","`n" -replace "`r","`n" | Set-Content -NoNewline -Encoding ascii $p
}

# ------------- Remover backups do índice (se já foram rastreados) -------------
Say "Removendo backups e TARs do índice (sem apagar do disco)"
TryRun { git rm -r --cached --ignore-unmatch backups } | Out-Null
TryRun { git rm -r --cached --ignore-unmatch *.tar } | Out-Null
TryRun { git rm -r --cached --ignore-unmatch *.tgz } | Out-Null

# ------------- Pull rebase (sincronizar) -------------
Say "Sincronizando com origin/main (pull --rebase)"
# cria main local se não existir
TryRun { git checkout -B main } | Out-Null
$pulled = TryRun { git pull --rebase origin main }
$pulled | Out-String | Write-Verbose

# ------------- Add/commit/tag/push -------------
Say "Stage de todas as mudanças"
git add -A

$status = git status --porcelain
if([string]::IsNullOrWhiteSpace($status)){
  Say "Nada para commitar (repo já está atualizado). Ainda assim, empurrando tags e branch."
} else {
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm"
  $msg = "chore(repo): full refresh — scripts Windows Unbound, configs, EOL e ignores ($ts)"
  Say "Commitando: $msg"
  git commit -m $msg
}

# Tag por timestamp (evita conflito com semver atual)
$tag = "v" + (Get-Date -Format "yyyyMMdd.HHmm")
Say "Criando tag: $tag"
TryRun { git tag -a $tag -m "Automated snapshot $tag" } | Out-Null

Say "Enviando para GitHub (origin main + tags)"
git push -u origin main
TryRun { git push origin --tags } | Out-Null

Say "Pronto! Repo atualizado."
