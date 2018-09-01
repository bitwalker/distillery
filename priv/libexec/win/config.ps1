# Sets config paths for sys.config and vm.args, and ensures that env var replacements are performed
function Configure-Release {
    # If a preconfigure hook calls back to the run control script, do not
    # try to init the configs again, as it will result in an infinite loop
    if ($Env:DISTILLERY_PRECONFIGURE -ne $null) {
        return
    }

    # Need to ensure pre_configure is run here, but
    # prevent recursion if the hook calls back to the run control script
    $Env:DISTILLERY_PRECONFIGURE = $true
    run-hooks -Phase pre_configure
    $Env:DISTILLERY_PRECONFIGURE = $null

    ## NOTE: Please read the following to understand what is going on here:
    # This code hides a great deal of implicit behavior, so it is important to
    # understand as much of the whole picture as possible.
    #
    # 1. Source config files must remain immutable, this is to ensure that when
    #    we replace environment variables in them, that these replacements do not
    #    become effectively permanent.
    # 2. We must not generate files when RELEASE_READ_ONLY is set
    # 3. We must respect the public shell script API, which includes SYS_CONFIG_PATH,
    #    and VMARGS_PATH. This means that if provided, we must use
    #    them as the source file, but we must update them to point to the m
    # 4. The upgrade installer script unpacks new config files, but attempts to use
    #    the sources defined here, rather than those included in the release. This is
    #    so that configuration is not blown away when the upgrade is applied, instead
    #    the new config file can be applied as needed. This of course could fail if a
    #    required config change is in the new files, but that is a change management issue,
    #    not one that we can solve in this script.
    #
    # For some additional discussion on the motivations behind this code, please review
    # https://github.com/bitwalker/issues/398 - the code under discussion there is already
    # out of date, but the conversation is still relevant now.

    # Set VMARGS_PATH, the path to the vm.args file to use
    # Use $RELEASE_CONFIG_DIR/vm.args if exists, otherwise releases/VSN/vm.args
    if ($Env:VMARGS_PATH -eq $null) {
        if (test-path (join-path $Env:RELEASE_CONFIG_DIR "vm.args")) {
            $Env:SRC_VMARGS_PATH = (join-path $Env:RELEASE_CONFIG_DIR "vm.args")
        } else {
            $Env:SRC_VMARGS_PATH = (join-path $Env:REL_DIR "vm.args")
        }
    } else {
        $Env:SRC_VMARGS_PATH = $Env:VMARGS_PATH
    }

    if ($Env:SRC_VMARGS_PATH -ne (join-path $Env:RELEASE_MUTABLE_DIR "vm.args")) {
        if ($Env:RELEASE_READ_ONLY -eq $null) {
            $Env:DEST_VMARGS_PATH = (join-path $Env:RELEASE_MUTABLE_DIR "vm.args")
            $header = "#### Generated - edit/create $Env:RELEASE_CONFIG_DIR/vm.args instead."
            $header | set-content -Path $Env:DEST_VMARGS_PATH
            get-content -Path $Env:SRC_VMARGS_PATH -Raw | add-content -Path $Env:DEST_VMARGS_PATH
        } else {
            $Env:DEST_VMARGS_PATH = $Env:SRC_VMARGS_PATH
        }
    }
    
    if (($Env:RELEASE_READ_ONLY -eq $null) -and ($Env:REPLACE_OS_VARS -ne $null)) {
        if ($Env:DEST_VMARGS_PATH -ne $null) {
            replace-os-vars -Path $Env:DEST_VMARGS_PATH
        }
    }
    if ($Env:DEST_VMARGS_PATH -ne $null) {
        $Env:VMARGS_PATH = $Env:DEST_VMARGS_PATH
    }

    # Set SYS_CONFIG_PATH, the path to the sys.config file to use
    # Use $RELEASE_CONFIG_DIR/sys.config if exists, otherwise releases/VSN/sys.config
    if ($Env:SYS_CONFIG_PATH -eq $null) {
        if (test-path (join-path $Env:RELEASE_CONFIG_DIR "sys.config")) {
            $Env:SRC_SYS_CONFIG_PATH = (join-path $Env:RELEASE_CONFIG_DIR "sys.config")
        } else {
            $Env:SRC_SYS_CONFIG_PATH = (join-path $Env:REL_DIR "sys.config")
        }
    } else {
        $Env:SRC_SYS_CONFIG_PATH = $Env:SYS_CONFIG_PATH
    }

    if (($Env:SRC_SYS_CONFIG_PATH -ne (join-path $Env:RELEASE_MUTABLE_DIR "sys.config"))) {
        if ($Env:RELEASE_READ_ONLY -eq $null) {
            $Env:DEST_SYS_CONFIG_PATH = (join-path $Env:RELEASE_MUTABLE_DIR "sys.config")
            $header = "%% Generated - edit/create $Env:RELEASE_CONFIG_DIR/sys.config instead."
            $header | set-content -Path $Env:DEST_SYS_CONFIG_PATH
            get-content -Path $Env:SRC_SYS_CONFIG_PATH -Raw | add-content -Path $Env:DEST_SYS_CONFIG_PATH
        } else {
            $Env:DEST_SYS_CONFIG_PATH = $Env:SRC_SYS_CONFIG_PATH
        }
    }

    if (($Env:RELEASE_READ_ONLY -eq $null) -and ($Env:REPLACE_OS_VARS -ne $null)) {
        if ($Env:DEST_SYS_CONFIG_PATH -ne $null) {
            replace-os-vars -Path $Env:DEST_SYS_CONFIG_PATH
        }
    }
    if ($Env:DEST_SYS_CONFIG_PATH -ne $null) {
        $Env:SYS_CONFIG_PATH = $Env:DEST_SYS_CONFIG_PATH
    }

    if ($Env:RELEASE_READ_ONLY -eq $null) {
        # Now that we have a full base config, run the config providers pass
        # This will replace the config at SYS_CONFIG_PATH with a fully provisioned config
        # Set the logger level to warning to prevent unnecessary output to stdio
        if ($Env:DEBUG_BOOT -eq $null) {
            erl -noshell -boot (join-path $Env:REL_DIR "config") -s erlang halt | out-null
            if (($LastExitCode -ne 0 ) -or (!$?)) {
                log-error "Unable to configure release!"
            }
        } else {
            erl -noshell -boot (join-path $Env:REL_DIR "config") -s erlang halt
            if (($LastExitCode -ne 0 ) -or (!$?)) {
                log-error "Unable to configure release!"
            }
        }
    }

    # Need to ensure post_configure is run here, but
    # prevent recursion if the hook calls back to the run control script
    $Env:DISTILLERY_PRECONFIGURE = $true
    run-hooks -Phase post_configure
    $Env:DISTILLERY_PRECONFIGURE = $null

    # Set up the node based on the new configuration
    configure-node
}

# Do a textual replacement of ${VAR} occurrences in $1 and pipe to $2
function Replace-Os-Vars() {
    param($Path = $(throw "You must provide -Path to Replace-Os-Vars"))

    $backup = ("{0}.bak" -f $Path)
    # Copy the source file to preserve permissions
    copy-item -Path $Path -Destination $backup -Force
    # Perform the replacement, rewriting $1.bak
    $replaced = get-content -Path $backup | foreach { 
        $line = $_
        # Extract every variable in the current line
        $vars = $line | select-string "\`${(?<var>[^}]+)}" | foreach { $_.Matches } | foreach { @{"var" = $_.Groups["var"].Value; "str" = $_.Groups[0].Value} }
        # Replace the content of that variable with the value from the env
        $vars | foreach { 
            $val = [Environment]::GetEnvironmentVariable($_["var"])
            $line = $line.Replace($_["str"], $val) 
        }
        # Output the updated line
        $line
    }
    $replaced | set-content -Path $backup
    # Replace the original file
    move-item -Path $backup -Destination $Path -Force
}


# Sets up the node name configuration for clustering/remote commands
function Configure-Node {
    # Extract the target node name from node.args
    # Should be `-sname somename` or `-name somename@somehost`
    $name_args = get-content -Path $Env:VMARGS_PATH | `
      select-string "^-(?<type>(sn|n)ame) (?<name>.+)$" | `
      foreach { $_.Matches } | `
      foreach { @{ "type" = $_.Groups["type"]; "name" = $_.Groups["name"] } }

    if ($name_args.Length -eq 0) {
        log-error "vm.args needs to have either the -name or -sname parameter defined"
    }
    
    $name = $name_args["name"]
    $name_type = $name_args["type"]

    $Env:NAME = $name
    $Env:NAME_TYPE = $name_type

    # User can specify an sname without @hostname
    # This will fail when creating remote shell
    # So here we check for @ and add @hostname if missing
    switch -Regex ($name) {
        # name@host
        '^[^@]+@[^\.]+$' {  
            if ($name_type -eq "name") {
                # -name was given, but the hostname is not fully qualified
                log-error "Failed setting -name! The hostname in '$Env:NAME' is not fully qualified"
            }
            break
        }
        # FQDN, e.g. name@host.com
        '^[^@]+@.+$' { break }
        # Short name
        default {
            $hostname = $Env:COMPUTERNAME
            if ($name_type -eq "$name") {
                if (-not (select-string -InputObject $hostname -Pattern "^[^\.]+\..*$" -SimpleMatch -Quiet)) {
                    # The hostname is not fully qualified, so change the name type
                    $Env:NAME_TYPE = "sname"
                }
            }
            $Env:NAME = ("{0}@{1}" -f $name,$hostname)
        }
    }
}

# Ensure that cookie is set.
function Require-Cookie {
    # Load cookie, if not already loaded
    load-cookie
    # Die if cookie is still not set, as connecting via distribution will fail
    if ($Env:COOKIE -eq $null) {
        log-error @"
A secret cookie must be provided in one of the following ways:

  - With vm.args using the -setcookie parameter
  - By writing the cookie to '$(join-path $Env:HOME ".erlang.cookie")', with permissions set to 0400
"@
    }
}

# Load target cookie, either from vm.args or $HOME/.cookie
function Load-Cookie {
    if ($Env:COOKIE -ne $null) {
        return
    }

    $cookie_arg = get-content -Path $Env:VMARGS_PATH | `
      select-string "^-setcookie (?<cookie>.+)$" | `
      foreach { $_.Matches } | `
      foreach { $_.Groups["cookie"].Value }
    
    if ($cookie_arg.Length -eq 0) {
        $default = (join-path $Env:HOME ".erlang.cookie")
    
        if (test-path $default) {
            $Env:COOKIE = (get-content -Path $default -Raw)
        } elseif ($Env:RELEASE_READ_ONLY -eq $null) {
            # Try generating one by starting the VM
            erl -noshell -$Env:NAME_TYPE $Env:NAME -s erlang halt | out-null
            if (!$?) {
                return false
            }
            $Env:COOKIE = (get-content -Path $default -Raw)
        }
        return
    }
    
    $Env:COOKIE = $cookie_arg
}
