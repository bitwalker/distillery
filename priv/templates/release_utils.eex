#!/usr/bin/env escript
%%! -noshell -noinput
%% -*- mode: erlang;erlang-indent-level: 4;indent-tabs-mode: nil -*-
%% ex: ft=erlang ts=4 sw=4 et

%% Build a list of code paths for the current release version
main(["get_code_paths", RootDir, ErtsDir, RelDir, RelName]) ->
    RelFile = filename:flatten([RelName, ".rel"]),
    {ok, [{release,_,_,Apps}]} = file:consult(filename:join([RelDir, RelFile])),
    lists:foreach(fun(A) ->
        AppName = erlang:atom_to_list(element(1, A)),
        AppVer  = element(2, A),
        case is_erts_lib(ErtsDir, AppName) of
            true ->
                AppPath = filename:join([ErtsDir, "..", "lib", filename:flatten([AppName, "-", AppVer])]);
            false ->
                AppPath = filename:join([RootDir, "lib", filename:flatten([AppName, "-", AppVer])])
        end,
        io:fwrite("-pa ~s \\", [AppPath])
    end, Apps),
    halt();
main(_) ->
    erlang:halt(1).

is_erts_lib(ErtsDir, AppName) ->
    LibDir = filename:join([ErtsDir, "..", "lib"]),
    Pattern = filename:flatten([AppName, "-*"]),
    case filelib:wildcard(filename:join([LibDir, Pattern])) of
        [] -> false;
        _  -> true
    end.
