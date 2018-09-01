# Ensures the current node is running, otherwise fails
function Require-Live-Node {
    if (-not (ping)) {
        log-error ("Node {0} is not running!" -f $Env:NAME)
    }
}

function Ping {
    require-cookie
    $argv = @()
    $argv += "--name=$Env:NAME"
    $argv += "--cookie=$Env:COOKIE"
    $argv += $args
    release-ctl ping @argv | out-null
    if ($LastExitCode -ne 0) {
        return $false
    }
    return $true
}

# Get node pid
function Get-Pid {
    $output = release-remote-ctl rpc ":os.getpid()"
    if ($LastExitCode -ne 0) {
        $output
    } else {
        $output -replace "`"",""
    }
}

# Generate a unique nodename
function Gen-NodeName {
    $id = gen-id
    $node, $rest = $Env:NAME.split("@")
    $nodehost = (-join $rest)
    if (($nodehost -eq "") -and ($Env:NAME_TYPE -eq "-name")) {
        # No hostname specified, and we're using long names, so use HOSTNAME
        "{0}-{1}@{2}" -f $node,$id,$Env:COMPUTERNAME
    } elseif ($nodehost -eq "") {
        # No hostname specified, but we're using -sname
        "{0}-{1}" -f $node,$id
    } elseif ($Env:NAME_TYPE -eq "-sname") {
        # Hostname specified, but we're using -sname
        "{0}-{1}" -f $node,$id
    } else {
        # Hostname specified, and we're using long names
        "{0}-{1}@{2}" -f $node,$id,$nodehost
    }
    return
}

# Print the current hostname
function Get-HostName {
    $null, $rest = $Env:NAME.split("@")
    $nodehost = (-join $rest)
    if ($nodehost -eq "") {
        $Env:COMPUTERNAME
    } else {
        $nodehost
    }
    return
}

# Generate a random id
function Gen-Id {
    get-random
}

## Run hooks for one of the configured startup phases
function Run-Hooks {
    param ($Phase = $(throw "You must set Phase when calling Run-Hooks!"))
    $phase_dir = (join-path $Env:HOOKS_DIR ("{0}.d" -f $Phase))
    if (test-path $phase_dir -PathType Container) {
        run-hooks-from-dir $phase_dir
    }
}

# Private. Run hooks from directory.
function Run-Hooks-From-Dir {
    param ($Dir = $(throw "You must set Dir when calling Run-Hooks-From-Dir"))
    get-childitem -Directory $Dir -Filter "*.ps1" | foreach { . $_.FullName }
}
