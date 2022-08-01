
function New-McdeRepository {
    if (Test-Path -Path out-repo) {
        Remove-Item -Recurse -Force out-repo
    }

    New-Item -Type Directory out-repo
    Push-Location out-repo
    git init
    git commit --allow-empty -m 'base commit' --author 'github-actions[bot] <github-actions[bot]@users.noreply.github.com>'
    Pop-Location
}

function Build-McdeProject {
    ./gradlew clean shadowJar -s
}


# $env:_JAVA_OPTIONS='-Djava.net.useSystemProxies=true'
$global:McdeUseMirror = $true

function Build-McdeDecompiledSource {
    [CmdletBinding()]
    param (
        [string] $Version,
        [string] $Uri
    )

    Write-Host "[$Version] Remapping jar"
    java -cp build/libs/gitmc.jar io.github.nickid2018.gitmc.RemapJar $Version $Uri ($global:McdeUseMirror ? 'true' : 'false')
    if (!$?) {
        Write-Error "Failed to remap $Version jar" -ErrorAction Stop
    }

    Write-Host "[$Version] Decompiling jar"
    $remappedName = "remapped-$Version.jar"
    java -cp build/libs/gitmc.jar org.benf.cfr.reader.Main --silent true --outputdir "tmp-$Version" --comments false $remappedName
    if (!$?) {
        Write-Error "Failed to cfr $Version jar" -ErrorAction Stop
    }

    Remove-Item ./mapping.txt, ./client.jar, "./$remappedName"
}

function Update-McdeGitRepository {
    [CmdletBinding()]
    param (
        [string] $Version
    )

    $rule = Get-Content ./version_rules.json | ConvertFrom-Json
    $target = 'master'

    if (Get-Member -InputObject $rule -MemberType Properties -Name $Version) {
        $rule_item = $rule | Select-Object -ExpandProperty $Version
        git rev-parse --verify $rule_item.branch
        if (!$?) {
            Push-Location ./out-repo
            $result = git log --all --grep $rule_item.base --pretty="%H"
            if ($result.Length -le 0) {
                Write-Error "Cannot find specified commit for base version $($rule_item.base)" -ErrorAction Stop
            }

            $sha = if ($result -is [array]) {
                $result[0]
            } else {
                $result
            }

            git branch $rule_item.branch $sha
            Pop-Location
        }
        $target = $rule_item.branch
    }

    Push-Location ./out-repo
    git switch $target
    git rm -rf '.'
    Copy-Item -Recurse -Path "../tmp-${Version}/*" -Destination .
    git add .
    git commit -m "$Version" --author 'github-actions[bot] <github-actions[bot]@users.noreply.github.com>'
    Pop-Location
}

function Get-McdeMinecraftManifest {
    $json = Invoke-WebRequest -Uri (Get-MirrorUri 'https://piston-meta.mojang.com/mc/game/version_manifest_v2.json')
    ConvertFrom-Json $json.Content
}

function Get-MirrorUri {
    param(
        [string] $Uri
    )

    if ($global:McdeUseMirror) {
        $newUri = [System.UriBuilder]::new($Uri)
        $newUri.Host = 'bmclapi2.bangbang93.com'

        $newUri.Uri.ToString()
    } else {
        $Uri
    }

}

function Build-McdeDecompilationTarget {

    param(
        [switch] $ExcludeSnapshot
    )

    $manifest = (Get-McdeMinecraftManifest).versions | Where-Object {$_.type -notin 'old_alpha', 'old_beta'}
    if ($ExcludeSnapshot) {
        $manifest = $manifest | Where-Object {$_.type -ne 'snapshot'}
    }

    $break_date = Get-Date '7/19/2019 5:00:00 PM'
    
    [System.Collections.ArrayList] $targets = @()

    foreach ($version in $manifest) {
        $version_data = Invoke-WebRequest -Uri (Get-MirrorUri $version.url) | ConvertFrom-Json
        $downloads = $version_data.downloads

        if ((Get-Date $version_data.releaseTime) -lt $break_date) {
            # No possible client mappings beyond this line
            break
        }

        if (Get-Member -InputObject $downloads -MemberType Properties -Name 'client_mappings') {
            Write-Host "[$($version_data.id)] is queued to build"
            [Void] $targets.Add([PSCustomObject] @{
                Id = $version_data.id
                Uri = $version.url
                ReleaseTime = $version_data.releaseTime
            })
        } else {
            break
        }
    }

    Write-Host "[Manifest] found $($targets.Count) versions to build"
    $targets
}

function reverse { 
    $arr = @($input)
    [array]::reverse($arr)
    $arr
}

function Build-McdeAllVersion {
    
    param (
        [switch] $ExcludeSnapshot,
        [switch] $NoMirror
    )

    $global:McdeUseMirror = !$NoMirror
    Write-Host "[Mirror] $global:McdeUseMirror"

    $targets = Build-McdeDecompilationTarget -ExcludeSnapshot $ExcludeSnapshot | reverse

    # ConvertTo-Json $targets | Set-Content -Path versionTable.json

    foreach ($v in $targets) {
        $time = Measure-Command {
            Write-Host -ForegroundColor Blue "[$($v.Id)] Start building"
            Write-Host $v

            Build-McdeDecompiledSource -Version $v.Id -Uri (Get-MirrorUri $v.Uri) -ErrorAction Stop
            Update-McdeGitRepository -Version $v.Id -ErrorAction Stop
            Remove-Item -Recurse -Path "./tmp-$($v.Id)"
        }

        Write-Host -ForegroundColor Green "[$($v.Id)] Finished in $($time.TotalSeconds)s"
    }
}
