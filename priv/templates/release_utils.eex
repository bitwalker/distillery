#!/usr/bin/env escript
%%! -noshell -noinput
%% -*- mode: erlang;erlang-indent-level: 4;indent-tabs-mode: nil -*-
%% ex: ft=erlang ts=4 sw=4 et

-define(TIMEOUT, 300000).
-define(INFO(Fmt,Args), io:format(Fmt,Args)).

%% Unpack or upgrade to a new tar.gz release
main(["unpack_release", RelName, NameTypeArg, NodeName, Cookie, VersionArg]) ->
    TargetNode = start_distribution(NodeName, NameTypeArg, Cookie),
    WhichReleases = which_releases(TargetNode),
    Version = parse_version(VersionArg),
    case proplists:get_value(Version, WhichReleases) of
        undefined ->
            %% not installed, so unpack tarball:
            ?INFO("Release ~s not found, attempting to unpack releases/~s/~s.tar.gz~n",[Version,Version,RelName]),
            ReleasePackage = Version ++ "/" ++ RelName,
            case rpc:call(TargetNode, release_handler, unpack_release,
                          [ReleasePackage], ?TIMEOUT) of
                {ok, Vsn} ->
                    ?INFO("Unpacked successfully: ~p~n", [Vsn]);
                {error, UnpackReason} ->
                    print_existing_versions(TargetNode),
                    ?INFO("Unpack failed: ~p~n",[UnpackReason]),
                    erlang:halt(2)
            end;
        old ->
            %% no need to unpack, has been installed previously
            ?INFO("Release ~s is already unpacked~n",[Version]);
        unpacked ->
            ?INFO("Release ~s is already unpacked~n",[Version]);
        current ->
            ?INFO("Release ~s is already unpacked~n",[Version]);
        permanent ->
            ?INFO("Release ~s is already unpacked~n",[Version])
    end;

%% Install a release and make it permanent
main(["install_release", RelName, NameTypeArg, NodeName, Cookie, VersionArg]) ->
    TargetNode = start_distribution(NodeName, NameTypeArg, Cookie),
    WhichReleases = which_releases(TargetNode),
    Version = parse_version(VersionArg),
    case proplists:get_value(Version, WhichReleases) of
        undefined ->
            %% not installed, so unpack tarball:
            ?INFO("Release ~s not found, attempting to unpack releases/~s/~s.tar.gz~n",[Version,Version,RelName]),
            ReleasePackage = Version ++ "/" ++ RelName,
            case rpc:call(TargetNode, release_handler, unpack_release,
                          [ReleasePackage], ?TIMEOUT) of
                {ok, Vsn} ->
                    ?INFO("Unpacked successfully: ~p~n", [Vsn]),
                    install_and_permafy(TargetNode, RelName, Vsn);
                {error, UnpackReason} ->
                    print_existing_versions(TargetNode),
                    ?INFO("Unpack failed: ~p~n",[UnpackReason]),
                    erlang:halt(2)
            end;
        old ->
            %% no need to unpack, has been installed previously
            ?INFO("Release ~s is marked old, switching to it.~n",[Version]),
            install_and_permafy(TargetNode, RelName, Version);
        unpacked ->
            ?INFO("Release ~s is already unpacked, now installing.~n",[Version]),
            install_and_permafy(TargetNode, RelName, Version);
        current -> %% installed and in-use, just needs to be permanent
            ?INFO("Release ~s is already installed and current. Making permanent.~n",[Version]),
            permafy(TargetNode, RelName, Version);
        permanent ->
            ?INFO("Release ~s is already installed, and set permanent.~n",[Version])
    end;

%% Build a list of code paths for the current release version
main(["get_code_paths", RootDir, ErtsDir, RelName, RelVsn]) ->
    {ok, {release,_,_,_,Libs,_}} = select_RELEASE(RootDir, ErtsDir, RelName, RelVsn),
    lists:foreach(fun({_LibName, _LibVer, LibDir}) ->
                        io:fwrite("-pa ~s/ebin ", [LibDir])
                  end, Libs);

%% Invalid command, return error
main(_) ->
    erlang:halt(1).

parse_version(V) when is_list(V) ->
    hd(string:tokens(V,"/")).

install_and_permafy(TargetNode, RelName, Vsn) ->
    case rpc:call(TargetNode, release_handler, check_install_release, [Vsn], ?TIMEOUT) of
        {ok, _OtherVsn, _Desc} ->
            ok;
        {error, Reason} ->
            ?INFO("ERROR: release_handler:check_install_release failed: ~p~n",[Reason]),
            erlang:halt(3)
    end,
    case rpc:call(TargetNode, release_handler, install_release,
                  [Vsn, [{update_paths, true}]], ?TIMEOUT) of
        {ok, _, _} ->
            ?INFO("Installed Release: ~s~n", [Vsn]),
            permafy(TargetNode, RelName, Vsn),
            ok;
        {error, {no_such_release, Vsn}} ->
            VerList =
                iolist_to_binary(
                    [io_lib:format("* ~s\t~s~n",[V,S]) ||  {V,S} <- which_releases(TargetNode)]),
            ?INFO("Installed versions:~n~s", [VerList]),
            ?INFO("ERROR: Unable to revert to '~s' - not installed.~n", [Vsn]),
            erlang:halt(2);
        %% As described in http://erlang.org/doc/man/appup.html,
        %% when executing a relup containing soft_purge instructions:
        %%     If the value is soft_purge, release_handler:install_release/1
        %%     returns {error, {old_processes, Mod}}
        {error, {old_processes, Mod}} ->
            ?INFO("ERROR: unable to install '~s' - old processes still running code from ~p~n",
                  [Vsn, Mod]),
            erlang:halt(3);
        {error, InstallFailedReason} ->
            ?INFO("ERROR: release_handler:install_release failed: ~p~n", [InstallFailedReason]),
            erlang:halt(3)
    end.

permafy(TargetNode, RelName, Vsn) ->
    ok = rpc:call(TargetNode, release_handler, make_permanent, [Vsn], ?TIMEOUT),
    file:copy(filename:join(["bin", RelName++"-"++Vsn]),
              filename:join(["bin", RelName])),
    ?INFO("Made release permanent: ~p~n", [Vsn]),
    ok.

which_releases(TargetNode) ->
    R = rpc:call(TargetNode, release_handler, which_releases, [], ?TIMEOUT),
    [ {V, S} ||  {_,V,_, S} <- R ].

print_existing_versions(TargetNode) ->
    VerList = iolist_to_binary([
            io_lib:format("* ~s\t~s~n",[V,S])
            ||  {V,S} <- which_releases(TargetNode) ]),
    ?INFO("Installed versions:~n~s", [VerList]).

start_distribution(NodeName, NameTypeArg, Cookie) ->
    MyNode = make_script_node(NodeName),
    {ok, _Pid} = net_kernel:start([MyNode, get_name_type(NameTypeArg)]),
    erlang:set_cookie(node(), list_to_atom(Cookie)),
    TargetNode = list_to_atom(NodeName),
    case {net_kernel:connect_node(TargetNode),
          net_adm:ping(TargetNode)} of
        {true, pong} ->
            ok;
        {_, pang} ->
            io:format("Node ~p not responding to pings.\n", [TargetNode]),
            erlang:halt(1)
    end,
    {ok, Cwd} = file:get_cwd(),
    ok = rpc:call(TargetNode, file, set_cwd, [Cwd], ?TIMEOUT),
    TargetNode.

make_script_node(Node) ->
    [Name, Host] = string:tokens(Node, "@"),
    list_to_atom(lists:concat([Name, "_upgrader_", os:getpid(), "@", Host])).

%% get name type from arg
get_name_type(NameTypeArg) ->
  case NameTypeArg of
    "-sname" ->
      shortnames;
    _ ->
      longnames
  end.

%% Selects a specific release from RELEASES
select_RELEASE(RootDir, ErtsDir, RelName, RelVsn) ->
    Releases = get_RELEASES(RootDir, ErtsDir),
    select_RELEASE(Releases, RelName, RelVsn).
select_RELEASE([], _RelName, _RelVsn) ->
    {error, no_such_release};
select_RELEASE([{release, RelName, RelVsn, _ErtsVsn, _Libs, _Status} = Release | _], RelName, RelVsn) ->
    {ok, Release};
select_RELEASE([_|Rest], RelName, RelVsn) ->
    select_RELEASE(Rest, RelName, RelVsn).


%% Gets the RELEASES file and returns it with all paths fixed
get_RELEASES(RootDir, ErtsDir) ->
    ReleasesFile = filename:join([RootDir, "releases", "RELEASES"]),
    {ok, [Releases]} = file:consult(ReleasesFile),
    FixedReleases = lists:map(fun(Release) ->
                                  fix_release(Release, RootDir, ErtsDir)
                              end, Releases),
    FixedReleases.

%% Used to fix invalid paths in RELEASES
fix_release({release, RelName, RelVsn, ErtsVsn, Libs, Status} = Release, RootDir, ErtsDir) ->
    CurrentErtsVsn = extract_erts_vsn(ErtsDir),
    case {string:rstr(ErtsDir, RootDir), CurrentErtsVsn} of
        {0, ErtsVsn} ->
            %% We are using the host ERTS, and it matches the ERTS version
            %% from RELEASES, which means we just need to make sure the path is up to date
            FixedLibs = lists:map(fun({LibName, LibVsn, _LibDir} = Lib) ->
                                        case is_erts_lib(ErtsDir, LibName) of
                                            true ->
                                                case get_erts_lib(ErtsDir, LibName, LibVsn) of
                                                    RealLibDir ->
                                                        {LibName, LibVsn, RealLibDir};
                                                    false ->
                                                        io:fwrite("Invalid RELEASES: could not find lib ~p~p in ~s.",
                                                            [LibName, LibVsn, ErtsDir])
                                                end;
                                            false ->
                                                Lib
                                        end
                                end, Libs),
            {release, RelName, RelVsn, ErtsVsn, FixedLibs, Status};
        {0, _Other} ->
            %% As stated here, we didn't include ERTS, and the host version does
            %% not match that of the host, this may not be a problem if the lib
            %% versions are the same and/or compatible, but we can't assume that
            io:fwrite("Invalid RELEASES: specified ERTS (~p) does not match host (~p).", [ErtsVsn, CurrentErtsVsn]),
            erlang:halt(2);
        {_, _} ->
            %% If we've included ERTS, we don't need to fix anything
            Release
    end;
fix_release(Release, _RootDir, _ErtsDir) ->
    Release.


%% Determines if the given app name is an ERTS lib
is_erts_lib(ErtsDir, AppName) ->
    LibDir = filename:join([ErtsDir, "..", "lib"]),
    Pattern = filename:flatten([AppName, "-*"]),
    case filelib:wildcard(filename:join([LibDir, Pattern])) of
        [] -> false;
        _  -> true
    end.

%% Returns the absolute path to an ERTS lib, or false if it doesn't exist
get_erts_lib(ErtsDir, AppName, AppVsn) ->
    LibDir = filename:join([ErtsDir, "..", "lib"]),
    Pattern = filename:flatten([AppName, "-", AppVsn]),
    case filelib:wildcard(filename:join([LibDir, Pattern])) of
        [] -> false;
        [AppDir] -> AppDir
    end.

%% Given a path to the ERTS directory, get the ERTS version number
extract_erts_vsn(ErtsDir) ->
    "erts-" ++ Vsn = filename:basename(ErtsDir),
    Vsn.
