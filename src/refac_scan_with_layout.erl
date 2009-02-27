%% ``The contents of this file are subject to the Erlang Public License,
%% Version 1.1, (the "License"); you may not use this file except in
%% compliance with the License. You should have received a copy of the
%% Erlang Public License along with this software. If not, it can be
%% retrieved via the world wide web at http://www.erlang.org/.
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and limitations
%% under the License.
%%
%% The Initial Developer of the Original Code is Ericsson Utvecklings AB.
%% Portions created by Ericsson are Copyright 1999, Ericsson Utvecklings
%% AB. All Rights Reserved.''
%%
%%     $Id: refac_scan.erl,v 1.5 2008-04-30 09:28:12 hl Exp $
%%
%% Modified: 17 Jan 2007 by  Huiqing Li <hl@kent.ac.uk>
%% 
%% 
%% Erlang token scanning functions of io library. This Lexer has been changed by
%% Huiqing Li to keep the comments and whitespaces in the token stream.

%% For handling ISO 8859-1 (Latin-1) we use the following type
%% information:
%%
%% 000 - 037	NUL - US	control
%% 040 - 057	SPC - /		punctuation
%% 060 - 071	0 - 9		digit
%% 072 - 100	: - @		punctuation
%% 101 - 132	A - Z		uppercase
%% 133 - 140	[ - `		punctuation
%% 141 - 172	a - z		lowercase
%% 173 - 176	{ - ~		punctuation
%% 177		DEL		control
%% 200 - 237			control
%% 240 - 277	NBSP - �	punctuation
%% 300 - 326	� - �		uppercase
%% 327		�		punctuation
%% 330 - 336	� - �		uppercase
%% 337 - 366	� - �		lowercase
%% 367		�		punctuation
%% 370 - 377	� - �		lowercase
%%
%% Many punctuation characters region have special meaning.  Must
%% watch using � \327, bvery close to x \170

-module(refac_scan_with_layout).

-export([string/1,string/2,string/3, tokens/3]).

-import(lists, [member/2, reverse/1]).

-define(DEFAULT_TABWIDTH, 8).

%% string(CharList, StartPos)
%%  Takes a list of characters and tries to tokenise them.
%%
%%  Returns:
%%	{ok,[Tok]}
%%	{error,{ErrorPos,?MODULE,What},EndPos}


string(Cs) ->
    string(Cs, {1, 1}, ?DEFAULT_TABWIDTH).

string(Cs, {Line, Col}) -> string(Cs, {Line, Col}, ?DEFAULT_TABWIDTH).

string(Cs, {Line, Col}, TabWidth)
    when is_list(Cs), is_integer(Line), is_integer(Col), is_integer(TabWidth) ->
    %     %% Debug replacement line for chopping string into 1-char segments
    %     scan([], [], [], Pos, Cs, []).
    scan(Cs, [], [], {Line, Col}, [], [],TabWidth).

%% tokens(Continuation, CharList, StartPos) ->
%%	{done, {ok, [Tok], EndPos}, Rest} |
%%	{done, {error,{ErrorPos,?MODULE,What}, EndPos}, Rest} |
%%	{more, Continuation'}
%%  This is the main function into the re-entrant scanner.
%%
%%  The continuation has the form:
%%      {RestChars,ScanStateStack,ScannedTokens,
%%       CurrentPos,ContState,ErrorStack,ContFunArity5}


%% definitely should sperate {Line, Col} and TabWidth;; HL.
tokens([], Chars, {{Line, Col}, TabWidth}) ->
    tokens({[], [], [], {Line, Col}, io, [], TabWidth, fun scan/7},
	   Chars, {{Line, Col}, TabWidth});
tokens({Cs, _Stack, _Toks, {Line, Col}, eof, TabWidth, _Fun}, eof,
       {_, TabWidth}) ->
    {done, {eof, {Line, Col}}, Cs};
tokens({Cs, Stack, Toks, {Line, Col}, _State, Errors,TabWidth,
	Fun},
       eof, {_, TabWidth}) ->
    Fun(Cs ++ eof, Stack, Toks, {Line, Col}, eof, Errors, TabWidth);
tokens({Cs, Stack, Toks, {Line, Col}, State, Errors,TabWidth,
	Fun},
       Chars, {_, TabWidth}) ->
    Fun(Cs ++ Chars, Stack, Toks, {Line, Col}, State,
	Errors, TabWidth).

%% Scan loop.
%%
%% The scan_*/7 and sub_scan_*/7 functions does tail recursive calls
%% between themselves to change state. State data is kept on the Stack.
%% Results are passed on the Stack and on the stream (Cs). The variable
%% State in this loop is not the scan loop state, but the state for
%% instream handling by more/8 and done/6. The variable Stack is not
%% always a stack, it is just stacked state data for the scan loop, and
%% the variable Errors is a reversed list of scan error {Error,Pos} tuples.
%%
%% All the scan_*/7 functions have the same arguments (in the same order),
%% to keep the tail recursive calls (jumps) fast.
%%
%% When more data is needed from the stream, the tail recursion loop is
%% broken by calling more/8 that either returns to the I/O-server to
%% get more data or fetches it from a string, or by calling done/6 when
%% scanning is done.
%%
%% The last argument to more/8 is a fun to jump back to with more data
%% to continue scanning where it was interrupted.
%%
%% more/8 and done/6 handles scanning from I/O-server (Stream) or from String.
%%

%% String
more(Cs, Stack, Toks, {Line, Col}, eos, Errors, _TabWidth, Fun) ->
    erlang:error(badstate,
		 [Cs, Stack, Toks, {Line, Col}, eos, Errors, Fun]);
% %% Debug clause for chopping string into 1-char segments
% more(Cs, Stack, Toks, Pos, [H|T], Errors, Fun) ->
%     Fun(Cs++[H], Stack, Toks, Pos, T, Errors);
more(Cs, Stack, Toks, {Line, Col}, [], Errors, TabWidth, Fun) ->
    Fun(Cs ++ eof, Stack, Toks, {Line, Col}, eos, Errors, TabWidth);
%% Stream
more(Cs, Stack, Toks, {Line, Col}, eof, Errors, TabWidth, Fun) ->
    erlang:error(badstate,
		 [Cs, Stack, Toks, {Line, Col}, eof, Errors, TabWidth, Fun]);
more(Cs, Stack, Toks, {Line, Col}, io, Errors, TabWidth, Fun) ->
    {more, {Cs, Stack, Toks, {Line, Col}, io, Errors, TabWidth, Fun}}.

%% String
done(eof, [], Toks, {Line, Col}, eos, _TabWidth) ->
    {ok, reverse(Toks), {Line, Col}};
done(eof, Errors, _Toks, {Line, Col}, eos, _TabWidth) ->
    {Error, ErrorPos} = lists:last(Errors),
    {error, {ErrorPos, ?MODULE, Error}, {Line, Col}};
done(Cs, Errors, Toks, {Line, Col}, eos, TabWidth) ->
    scan(Cs, [], Toks, {Line, Col}, eos, Errors, TabWidth);
% %% Debug clause for chopping string into 1-char segments
% done(Cs, Errors, Toks, Pos, [H|T]) ->
%    scan(Cs++[H], [], Toks, Pos, T, Errors);
done(Cs, Errors, Toks, {Line, Col}, [], TabWidth) ->
    scan(Cs ++ eof, [], Toks, {Line, Col}, eos, Errors, TabWidth);
%% Stream
done(Cs, [], [{dot, _} | _] = Toks, {Line, Col}, io, _TabWidth) ->
    {done, {ok, reverse(Toks), {Line, Col}}, Cs};
done(Cs, [], [_ | _], {Line, Col}, io, _TabWidth) ->
    {done,
     {error, {{Line, Col}, ?MODULE, scan}, {Line, Col}}, Cs};
done(Cs, [], [], {Line, Col}, eof, _TabWidth) ->
    {done, {eof, {Line, Col}}, Cs};
done(Cs, [], [{dot, _} | _] = Toks, {Line, Col}, eof, _TabWidth) ->
    {done, {ok, reverse(Toks), {Line, Col}}, Cs};
done(Cs, [], _Toks, {Line, Col}, eof, _TabWidth) ->
    {done,
     {error, {{Line, Col}, ?MODULE, scan}, {Line, Col}}, Cs};
done(Cs, Errors, _Toks, {Line, Col}, io, _TabWidth) ->
    {Error, ErrorPos} = lists:last(Errors),
    {done, {error, {ErrorPos, ?MODULE, Error}, {Line, Col}},
     Cs};
done(Cs, Errors, _Toks, {Line, Col}, eof, _TabWidth) ->
    {Error, ErrorPos} = lists:last(Errors),
    {done, {error, {ErrorPos, ?MODULE, Error}, {Line, Col}},
     Cs}.

%% The actual scan loop
%% Stack is assumed to be [].

scan([$\n | Cs], Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->      % Newline - skip
    scan(Cs, Stack, [{whitespace, {Line, Col}, '\n'}|Toks], {Line + 1, 1}, State, Errors, TabWidth);  

%%Begin of Adding by Huiqing
scan([C | Cs], Stack, Toks, {Line, Col}, State, Errors, TabWidth)
    when C == $\t
	  ->                          
    scan(Cs, Stack, [{whitespace, {Line, Col}, '\t'}|Toks], {Line, Col + TabWidth}, State, Errors, TabWidth);
%% End of adding by Huiqing

scan([C | Cs], Stack, Toks, {Line, Col}, State, Errors, TabWidth)
    when C >= $\000,
	 C =<
	   $\s ->                          % Control chars - skip
    case C of 
	$\s  -> scan(Cs, Stack, [{whitespace, {Line,Col}, ' '}|Toks], {Line, Col + 1}, State, Errors, TabWidth);
	_ ->scan(Cs, Stack, Toks, {Line, Col + 1}, State, Errors, TabWidth )
    end;

scan([C | Cs], Stack, Toks, {Line, Col}, State, Errors, TabWidth)
    when C >= $\200,
	 C =< $\240 ->                        % Control chars -skip
    scan(Cs, Stack, [{whitespace, {Line,Col}, C}|Toks], {Line, Col + 1}, State, Errors, TabWidth);
scan([C | Cs], _Stack, Toks, {Line, Col}, State, Errors, TabWidth)
    when C >= $a,
	 C =< $z ->                              % Atoms
    sub_scan_name(Cs, [C, fun scan_atom/7], Toks,
		  {Line, Col}, State, Errors, TabWidth);
scan([C | Cs], _Stack, Toks, {Line, Col}, State, Errors, TabWidth)
    when C >= $�, C =< $�,
	 C /= $� ->                     % Atoms
    sub_scan_name(Cs, [C, fun scan_atom/7], Toks,
		  {Line, Col}, State, Errors, TabWidth);
scan([C | Cs], _Stack, Toks, {Line, Col}, State, Errors, TabWidth)
    when C >= $A,
	 C =< $Z ->                              % Variables
    sub_scan_name(Cs, [C, fun scan_variable/7], Toks,
		  {Line, Col}, State, Errors, TabWidth);
scan([C | Cs], _Stack, Toks, {Line, Col}, State, Errors, TabWidth)
    when C >= $�, C =< $�,
	 C /= $� ->                     % Variables
    sub_scan_name(Cs, [C, fun scan_variable/7], Toks,
		  {Line, Col}, State, Errors, TabWidth);
scan([$_ | Cs], _Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->      % _Variables
    sub_scan_name(Cs, [$_, fun scan_variable/7], Toks,
		  {Line, Col}, State, Errors, TabWidth);
scan([C | Cs], _Stack, Toks, {Line, Col}, State, Errors, TabWidth)
    when C >= $0,
	 C =< $9 ->                            % Numbers
    scan_number(Cs, [C], Toks, {Line, Col}, State, Errors, TabWidth);
scan([$$ | Cs], Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->        % Character constant
    scan_char(Cs, Stack, Toks, {Line, Col+2}, State, Errors, TabWidth);
scan([$' | Cs], _Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->      % Quoted atom
    scan_qatom(Cs, [$', {Line, Col}], Toks, {Line, Col+1},
	       State, Errors, TabWidth);
scan([$" | Cs], _Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->      % String
    scan_string(Cs, [$", {Line, Col}], Toks, {Line, Col+1},
		State, Errors, TabWidth);
scan([$% | Cs], _Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->       % Comment
    scan_comment(Cs, [$%, {Line, Col}], Toks, {Line, Col+1}, State,
		 Errors, TabWidth);
%% Punctuation characters and operators, first recognise multiples.
%% Clauses are rouped by first character (a short with the same head has
%% to come after a longer).
%%
%% << <- <=
scan("<<" ++ Cs, Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->
    scan(Cs, Stack, [{'<<', {Line, Col}} | Toks],
	 {Line, Col + 2}, State, Errors, TabWidth);
scan("<-" ++ Cs, Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->
    scan(Cs, Stack, [{'<-', {Line, Col}} | Toks],
	 {Line, Col + 2}, State, Errors, TabWidth);
scan("<=" ++ Cs, Stack, Toks, {Line, Col}, State,TabWidth,
     Errors) ->
    scan(Cs, Stack, [{'<=', {Line, Col}} | Toks],
	 {Line, Col + 2}, State, Errors, TabWidth);
scan("<" = Cs, Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->
    more(Cs, Stack, Toks, {Line, Col}, State, Errors, TabWidth,
	 fun scan/7);
%% >> >=
scan(">>" ++ Cs, Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->
    scan(Cs, Stack, [{'>>', {Line, Col}} | Toks],
	 {Line, Col + 2}, State, Errors, TabWidth);
scan(">=" ++ Cs, Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->
    scan(Cs, Stack, [{'>=', {Line, Col}} | Toks],
	 {Line, Col + 2}, State, Errors, TabWidth);
scan(">" = Cs, Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->
    more(Cs, Stack, Toks, {Line, Col}, State, Errors,TabWidth,
	 fun scan/7);
%% -> --
scan("->" ++ Cs, Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->
    scan(Cs, Stack, [{'->', {Line, Col}} | Toks],
	 {Line, Col + 2}, State, Errors, TabWidth);
scan("--" ++ Cs, Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->
    scan(Cs, Stack, [{'--', {Line, Col}} | Toks],
	 {Line, Col + 2}, State, Errors, TabWidth);
scan("-" = Cs, Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->
    more(Cs, Stack, Toks, {Line, Col}, State, Errors,TabWidth,
	 fun scan/7);
%% ++
scan("++" ++ Cs, Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->
    scan(Cs, Stack, [{'++', {Line, Col}} | Toks],
	 {Line, Col + 2}, State, Errors, TabWidth);
scan("+" = Cs, Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->
    more(Cs, Stack, Toks, {Line, Col}, State, Errors,TabWidth,
	 fun scan/7);
%% =:= =/= =< ==
scan("=:=" ++ Cs, Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->
    scan(Cs, Stack, [{'=:=', {Line, Col}} | Toks],
	 {Line, Col + 3}, State, Errors, TabWidth);
scan("=:" = Cs, Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->
    more(Cs, Stack, Toks, {Line, Col}, State, Errors,TabWidth,
	 fun scan/7);
scan("=/=" ++ Cs, Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->
    scan(Cs, Stack, [{'=/=', {Line, Col}} | Toks],
	 {Line, Col + 3}, State, Errors, TabWidth);
scan("=/" = Cs, Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->
    more(Cs, Stack, Toks, {Line, Col}, State, Errors, TabWidth,
	 fun scan/7);
scan("=<" ++ Cs, Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->
    scan(Cs, Stack, [{'=<', {Line, Col}} | Toks],
	 {Line, Col + 2}, State, Errors, TabWidth);
scan("==" ++ Cs, Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->
    scan(Cs, Stack, [{'==', {Line, Col}} | Toks],
	 {Line, Col + 2}, State, Errors, TabWidth);
scan("=" = Cs, Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->
    more(Cs, Stack, Toks, {Line, Col}, State, Errors,TabWidth, 
	 fun scan/7);
%% /=
scan("/=" ++ Cs, Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->
    scan(Cs, Stack, [{'/=', {Line, Col}} | Toks],
	 {Line, Col + 2}, State, Errors, TabWidth);
scan("/" = Cs, Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->
    more(Cs, Stack, Toks, {Line, Col}, State, Errors,TabWidth,
	 fun scan/7);
%% ||
scan("||" ++ Cs, Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->
    scan(Cs, Stack, [{'||', {Line, Col}} | Toks],
	 {Line, Col + 2}, State, Errors, TabWidth);
scan("|" = Cs, Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->
    more(Cs, Stack, Toks, {Line, Col}, State, Errors,TabWidth,
	 fun scan/7);
%% :-
scan(":-" ++ Cs, Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->
    scan(Cs, Stack, [{':-', {Line, Col}} | Toks],
	 {Line, Col + 2}, State, Errors, TabWidth);
%% :: for typed records
scan("::"++Cs, Stack, Toks, {Line, Col}, State, Errors, TabWidth) ->
    scan(Cs, Stack, [{'::',{Line, Col}}|Toks], {Line, Col+2}, State, Errors, TabWidth);

scan(":" = Cs, Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->
    more(Cs, Stack, Toks, {Line, Col}, State, Errors, TabWidth,
	 fun scan/7);
%% Full stop and plain '.'
scan("." ++ Cs, Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->
    scan_dot(Cs, Stack, Toks, {Line, Col}, State, Errors, TabWidth);
%% All single-char punctuation characters and operators (except '.')
scan([C | Cs], Stack, Toks, {Line, Col}, State,
     Errors, TabWidth) ->
    scan(Cs, Stack,
	 [{list_to_atom([C]), {Line, Col}} | Toks],
	 {Line, Col + 1}, State, Errors, TabWidth);
%%
scan([], Stack, Toks, {Line, Col}, State, Errors, TabWidth) ->
    more([], Stack, Toks, {Line, Col}, State, Errors, TabWidth,
	 fun scan/7);
scan(Eof, _Stack, Toks, {Line, Col}, State, Errors, TabWidth) ->
    done(Eof, Errors, Toks, {Line, Col}, State, TabWidth).

scan_atom(Cs, Name, Toks, {Line, Col}, State, Errors, TabWidth) ->
    case catch list_to_atom(Name) of
      Atom when is_atom(Atom) ->
	  case reserved_word(Atom) of
	    true ->
		scan(Cs, [], [{Atom, {Line, Col}} | Toks],
		     {Line, Col + length(Name)}, State, Errors, TabWidth);
	    false ->
		scan(Cs, [], [{atom, {Line, Col}, Atom} | Toks],
		     {Line, Col + length(Name)}, State, Errors, TabWidth)
	  end;
      _ ->
	  scan(Cs, [], Toks, {Line, Col}, State,
	       [{{illegal, atom}, {Line, Col}} | Errors], TabWidth)
    end.

scan_variable(Cs, Name, Toks, {Line, Col}, State,
	      Errors, TabWidth) ->
    case catch list_to_atom(Name) of
      A when is_atom(A) ->
	  scan(Cs, [], [{var, {Line, Col}, A} | Toks],
	       {Line, Col + length(Name)}, State, Errors, TabWidth);
      _ ->
	  scan(Cs, [], Toks, {Line, Col}, State,
	       [{{illegal, var}, {Line, Col}} | Errors], TabWidth)
    end.

%% Scan for a name - unqouted atom or variable, after the first character.
%%
%% Stack argument: return fun.
%% Returns the scanned name on the stack, unreversed.
%%
sub_scan_name([C | Cs] = Css, Stack, Toks, {Line, Col},
	      State, Errors, TabWidth) ->
    case name_char(C) of
      true ->
	  sub_scan_name(Cs, [C | Stack], Toks, {Line, Col}, State,
			Errors, TabWidth);
      false ->
	  [Fun | Name] = reverse(Stack),
	  Fun(Css, Name, Toks, {Line, Col}, State, Errors, TabWidth)
    end;
sub_scan_name([], Stack, Toks, {Line, Col}, State,
	      Errors, TabWidth) ->
    more([], Stack, Toks, {Line, Col}, State, Errors, TabWidth,
	 fun sub_scan_name/7);
sub_scan_name(Eof, Stack, Toks, {Line, Col}, State,
	      Errors, TabWidth) ->
    [Fun | Name] = reverse(Stack),
    Fun(Eof, Name, Toks, {Line, Col}, State, Errors, TabWidth).

name_char(C) when C >= $a, C =< $z -> true;
name_char(C) when C >= $�, C =< $�, C /= $� -> true;
name_char(C) when C >= $A, C =< $Z -> true;
name_char(C) when C >= $�, C =< $�, C /= $� -> true;
name_char(C) when C >= $0, C =< $9 -> true;
name_char($_) -> true;
name_char($@) -> true;
name_char(_) -> false.

scan_char([$\\ | Cs], Stack, Toks, {Line, Col}, State,
	  Errors, TabWidth) ->
    sub_scan_escape(Cs, [fun scan_char_escape/7 | Stack],
		    Toks, {Line, Col}, State, Errors, TabWidth);
scan_char([$\n | Cs], Stack, Toks, {Line, Col}, State,
	  Errors, TabWidth) ->
    scan(Cs, Stack, [{char, {Line, Col}, $\n} | Toks],
	 {Line + 1, Col}, State, Errors, TabWidth);
scan_char([], Stack, Toks, {Line, Col}, State,
	  Errors, TabWidth) ->
    more([], Stack, Toks, {Line, Col}, State, Errors,TabWidth,
	 fun scan_char/7);
scan_char(Cs, Stack, Toks, {Line, Col}, State,
	  Errors, TabWidth) ->
    scan_char_escape(Cs, Stack, Toks, {Line, Col}, State,
		     Errors, TabWidth).

scan_char_escape([nl | Cs], Stack, Toks, {Line, Col},
		 State, Errors, TabWidth) ->
    scan(Cs, Stack, [{char, {Line, Col}, $\n} | Toks],
	 {Line + 1, Col}, State, Errors, TabWidth);
scan_char_escape([C | Cs], Stack, Toks, {Line, Col},
		 State, Errors, TabWidth) ->
    scan(Cs, Stack, [{char, {Line, Col}, C} | Toks],
	 {Line, Col + 1}, State, Errors, TabWidth);
scan_char_escape(Eof, _Stack, _Toks, {Line, Col}, State,
		 Errors, TabWidth) ->
    done(Eof, [{char, {Line, Col}} | Errors], [],
	 {Line, Col + 1}, State, TabWidth).

scan_string([$" | Cs], Stack, Toks, {Line, Col}, State,
	    Errors, TabWidth) ->
    [StartPos, $" | S] = reverse(Stack),
    scan(Cs, [], [{string, StartPos, S} | Toks],
	 {Line, Col + length(io_lib:write_string(S)) -1}, State, Errors, TabWidth);
scan_string([$\n | Cs], Stack, Toks, {Line, _Col}, State,
	    Errors, TabWidth) ->
    scan_string(Cs, [$\n | Stack], Toks, {Line + 1, 1},
		State, Errors, TabWidth);
scan_string([$\\ | Cs], Stack, Toks, {Line, Col}, State,
	    Errors, TabWidth) ->
    sub_scan_escape(Cs, [fun scan_string_escape/7 | Stack],
		    Toks, {Line, Col}, State, Errors, TabWidth);
scan_string([C | Cs], Stack, Toks, {Line, Col}, State,
	    Errors, TabWidth) ->
    scan_string(Cs, [C | Stack], Toks, {Line, Col}, State,
		Errors, TabWidth);
scan_string([], Stack, Toks, {Line, Col}, State,
	    Errors, TabWidth) ->
    more([], Stack, Toks, {Line, Col}, State, Errors, TabWidth,
	 fun scan_string/7);
scan_string(Eof, Stack, _Toks, {Line, Col}, State,
	    Errors, TabWidth) ->
    [StartPos, $" | S] = reverse(Stack),
    SS = string:substr(S, 1, 16),
    done(Eof, [{{string, $", SS}, StartPos} | Errors], [],
	 {Line, Col + length(io_lib:write_string(S)) -1}, State, TabWidth).

scan_string_escape([nl | Cs], Stack, Toks, {Line, _Col},
		   State, Errors, TabWidth) ->
    scan_string(Cs, [$\n | Stack], Toks, {Line + 1, 1},
		State, Errors, TabWidth);
scan_string_escape([C | Cs], Stack, Toks, {Line, Col},
		   State, Errors, TabWidth) ->
    scan_string(Cs, [C | Stack], Toks, {Line, Col}, State,
		Errors, TabWidth);
scan_string_escape(Eof, Stack, _Toks, {Line, Col},
		   State, Errors, TabWidth) ->
    [StartPos, $" | S] = reverse(Stack),
    SS = string:substr(S, 1, 16),
    done(Eof, [{{string, $", SS}, StartPos} | Errors], [],
	 {Line, Col + length(S) + 2}, State, TabWidth).

scan_qatom([$' | Cs], Stack, Toks, {Line, Col}, State,
	   Errors, TabWidth) ->
    [StartPos, $' | S] = reverse(Stack),
    case catch list_to_atom(S) of
      A when is_atom(A) ->
	  scan(Cs, [], [{qatom, StartPos, A} | Toks],
	       {Line, Col + length(S) + 1}, State, Errors, TabWidth);
      _ ->
	  scan(Cs, [], Toks, {Line, Col}, State,
	       [{{illegal, atom}, StartPos} | Errors], TabWidth)
    end;
scan_qatom([$\n | Cs], Stack, Toks, {Line, _Col}, State,
	   Errors, TabWidth) ->
    scan_qatom(Cs, [$\n | Stack], Toks, {Line + 1, 1},
	       State, Errors, TabWidth);
scan_qatom([$\\ | Cs], Stack, Toks, {Line, Col}, State,
	   Errors, TabWidth) ->
    sub_scan_escape(Cs, [fun scan_qatom_escape/7 | Stack],
		    Toks, {Line, Col}, State, Errors, TabWidth);
scan_qatom([C | Cs], Stack, Toks, {Line, Col}, State,
	   Errors, TabWidth) ->
    scan_qatom(Cs, [C | Stack], Toks, {Line, Col}, State,
	       Errors, TabWidth);
scan_qatom([], Stack, Toks, {Line, Col}, State,
	   Errors, TabWidth) ->
    more([], Stack, Toks, {Line, Col}, State, Errors, TabWidth,
	 fun scan_qatom/7);
scan_qatom(Eof, Stack, _Toks, {Line, Col}, State,
	   Errors, TabWidth) ->
    [StartPos, $' | S] = reverse(Stack),
    SS = string:substr(S, 1, 16),
    done(Eof, [{{string, $', SS}, StartPos} | Errors], [],
	 {Line, Col + length(S) + 1}, State, TabWidth ).

scan_qatom_escape([nl | Cs], Stack, Toks, {Line, _Col},
		  State, Errors, TabWidth) ->
    scan_qatom(Cs, [$\n | Stack], Toks, {Line + 1, 1},
	       State, Errors, TabWidth);
scan_qatom_escape([C | Cs], Stack, Toks, {Line, Col},
		  State, Errors, TabWidth) ->
    scan_qatom(Cs, [C | Stack], Toks, {Line, Col}, State,
	       Errors, TabWidth);
scan_qatom_escape(Eof, Stack, _Toks, {Line, Col}, State,
		  Errors, TabWidth) ->
    [StartPos, $' | S] = reverse(Stack),
    SS = string:substr(S, 1, 16),
    done(Eof, [{{string, $', SS}, StartPos} | Errors], [],
	 {Line, Col + length(S) + 1}, State, TabWidth).

%% Scan for a character escape sequence, in character literal or string.
%% A string is a syntactical sugar list (e.g "abc")
%% or a quoted atom (e.g 'EXIT').
%%
%% Stack argument: return fun.
%% Returns the resulting escape character on the stream.
%% The return atom 'nl' means that the escape sequence Backslash Newline
%% was found, i.e an actual Newline in the input.
%%
%% \<1-3> octal digits
sub_scan_escape([O1, O2, O3 | Cs], [Fun | Stack], Toks,
		{Line, Col}, State, Errors, TabWidth)
    when O1 >= $0, O1 =< $7, O2 >= $0, O2 =< $7, O3 >= $0,
	 O3 =< $7 ->
    Val = (O1 * 8 + O2) * 8 + O3 - 73 * $0,
    Fun([Val | Cs], Stack, Toks, {Line, Col}, State,
	Errors, TabWidth);
sub_scan_escape([O1, O2] = Cs, Stack, Toks, {Line, Col},
		State, Errors, TabWidth)
    when O1 >= $0, O1 =< $7, O2 >= $0, O2 =< $7 ->
    more(Cs, Stack, Toks, {Line, Col}, State, Errors, TabWidth,
	 fun sub_scan_escape/7);
sub_scan_escape([O1, O2 | Cs], [Fun | Stack], Toks,
		{Line, Col}, State, Errors, TabWidth)
    when O1 >= $0, O1 =< $7, O2 >= $0, O2 =< $7 ->
    Val = O1 * 8 + O2 - 9 * $0,
    Fun([Val | Cs], Stack, Toks, {Line, Col}, State,
	Errors, TabWidth);
sub_scan_escape([O1] = Cs, Stack, Toks, {Line, Col},
		State, Errors, TabWidth)
    when O1 >= $0, O1 =< $7 ->
    more(Cs, Stack, Toks, {Line, Col}, State, Errors, TabWidth,
	 fun sub_scan_escape/7);
sub_scan_escape([O1 | Cs], [Fun | Stack], Toks,
		{Line, Col}, State, Errors, TabWidth)
    when O1 >= $0, O1 =< $7 ->
    Val = O1 - $0,
    Fun([Val | Cs], Stack, Toks, {Line, Col}, State,
	Errors, TabWidth);
%% \^X -> CTL-X
sub_scan_escape([$^, C | Cs], [Fun | Stack], Toks,
		{Line, Col}, State, Errors, TabWidth) ->
    Val = C band 31,
    Fun([Val | Cs], Stack, Toks, {Line, Col}, State,
	Errors, TabWidth);
sub_scan_escape([$^] = Cs, Stack, Toks, {Line, Col},
		State, Errors, TabWidth) ->
    more(Cs, Stack, Toks, {Line, Col}, State, Errors, TabWidth,
	 fun sub_scan_escape/7);
sub_scan_escape([$^ | Eof], [Fun | Stack], Toks,
		{Line, Col}, State, Errors, TabWidth) ->
    Fun(Eof, Stack, Toks, {Line, Col}, State, Errors, TabWidth);
%% \NL (backslash newline)
sub_scan_escape([$\n | Cs], [Fun | Stack], Toks,
		{Line, Col}, State, Errors, TabWidth) ->
    Fun([nl | Cs], Stack, Toks, {Line, Col}, State, Errors, TabWidth);
%% \X - familiar escape sequences
sub_scan_escape([C | Cs], [Fun | Stack], Toks,
		{Line, Col}, State, Errors, TabWidth) ->
    Val = escape_char(C),
    Fun([Val | Cs], Stack, Toks, {Line, Col}, State,
	Errors, TabWidth);
%%
sub_scan_escape([], Stack, Toks, {Line, Col}, State,
		Errors, TabWidth) ->
    more([], Stack, Toks, {Line, Col}, State, Errors, TabWidth,
	 fun sub_scan_escape/7);
sub_scan_escape(Eof, [Fun | Stack], Toks, {Line, Col},
		State, Errors, TabWidth) ->
    Fun(Eof, Stack, Toks, {Line, Col}, State, Errors, TabWidth).

escape_char($n) -> $\n;                         %\n = LF
escape_char($r) -> $\r;                         %\r = CR
escape_char($t) ->
    $\t;                         %\t = TAB
escape_char($v) -> $\v;                         %\v = VT
escape_char($b) -> $\b;                         %\b = BS
escape_char($f) -> $\f;                         %\f = FF
escape_char($e) ->
    $\e;                         %\e = ESC
escape_char($s) ->
    $\s;                         %\s = SPC
escape_char($d) ->
    $\d;                         %\d = DEL
escape_char(C) -> C.

scan_number([$., C | Cs], Stack, Toks, {Line, Col},
	    State, Errors, TabWidth)
    when C >= $0, C =< $9 ->
    scan_fraction(Cs, [C, $. | Stack], Toks, {Line, Col},
		  State, Errors, TabWidth);
scan_number([$.] = Cs, Stack, Toks, {Line, Col}, State,
	    Errors, TabWidth) ->
    more(Cs, Stack, Toks, {Line, Col}, State, Errors,TabWidth,
	 fun scan_number/7);
scan_number([C | Cs], Stack, Toks, {Line, Col}, State,
	    Errors, TabWidth)
    when C >= $0, C =< $9 ->
    scan_number(Cs, [C | Stack], Toks, {Line, Col}, State,
		Errors, TabWidth);
scan_number([$# | Cs], Stack, Toks, {Line, Col}, State,
	    Errors, TabWidth) ->
    case catch list_to_integer(reverse(Stack)) of
      B when is_integer(B), B >= 2, B =< 1 + $Z - $A + 10 ->
	  scan_based_int(Cs, [B], Toks, {Line, Col}, State,
			 Errors, TabWidth);
      B ->
	  scan(Cs, [], Toks, {Line, Col}, State,
	       [{{base, B}, {Line, Col}} | Errors], TabWidth)
    end;
scan_number([], Stack, Toks, {Line, Col}, State,
	    Errors, TabWidth) ->
    more([], Stack, Toks, {Line, Col}, State, Errors,TabWidth,
	 fun scan_number/7);
scan_number(Cs, Stack, Toks, {Line, Col}, State,
	    Errors, TabWidth) ->
    case catch list_to_integer(reverse(Stack)) of
      N when is_integer(N) ->
	  scan(Cs, [], [{integer, {Line, Col}, N} | Toks],
	       {Line, Col + length(Stack)}, State, Errors, TabWidth);
      _ ->
	  scan(Cs, [], Toks, {Line, Col}, State,
	       [{{illegal, integer}, {Line, Col}} | Errors], TabWidth)
    end.

scan_based_int([C | Cs], [B | Stack], Toks, {Line, Col},
	       State, Errors, TabWidth)
    when C >= $0, C =< $9, C < $0 + B ->
    scan_based_int(Cs, [B, C | Stack], Toks, {Line, Col},
		   State, Errors, TabWidth);
scan_based_int([C | Cs], [B | Stack], Toks, {Line, Col},
	       State, Errors, TabWidth)
    when C >= $A, B > 10, C < $A + B - 10 ->
    scan_based_int(Cs, [B, C | Stack], Toks, {Line, Col},
		   State, Errors, TabWidth);
scan_based_int([C | Cs], [B | Stack], Toks, {Line, Col},
	       State, Errors, TabWidth)
    when C >= $a, B > 10, C < $a + B - 10 ->
    scan_based_int(Cs, [B, C | Stack], Toks, {Line, Col},
		   State, Errors, TabWidth);
scan_based_int([], Stack, Toks, {Line, Col}, State,
	       Errors, TabWidth) ->
    more([], Stack, Toks, {Line, Col}, State, Errors, TabWidth,
	 fun scan_based_int/7);
scan_based_int(Cs, [B | Stack], Toks, {Line, Col},
	       State, Errors, TabWidth) ->
    case catch erlang:list_to_integer(reverse(Stack), B) of
	N when is_integer(N) ->
	    scan(Cs, [], [{integer, {Line, Col}, 
			   integer_to_list(B)++[$#| reverse(Stack)]} | Toks],   %% "replaced 'N' with 'reverse(Stack)'";
		 {Line, Col + length(Stack)}, State, Errors, TabWidth);
	_ ->
	  scan(Cs, [], Toks, {Line, Col}, State,
	       [{{illegal, integer}, {Line, Col}} | Errors], TabWidth)
    end.

scan_fraction([C | Cs], Stack, Toks, {Line, Col}, State,
	      Errors, TabWidth)
    when C >= $0, C =< $9 ->
    scan_fraction(Cs, [C | Stack], Toks, {Line, Col}, State,
		  Errors, TabWidth);
scan_fraction([$e | Cs], Stack, Toks, {Line, Col},
	      State, Errors, TabWidth) ->
    scan_exponent_sign(Cs, [$E | Stack], Toks, {Line, Col},
		       State, Errors,TabWidth);
scan_fraction([$E | Cs], Stack, Toks, {Line, Col},
	      State, Errors, TabWidth ) ->
    scan_exponent_sign(Cs, [$E | Stack], Toks, {Line, Col},
		       State, Errors, TabWidth);
scan_fraction([], Stack, Toks, {Line, Col}, State,
	      Errors, TabWidth) ->
    more([], Stack, Toks, {Line, Col}, State, Errors,TabWidth,
	 fun scan_fraction/7);
scan_fraction(Cs, Stack, Toks, {Line, Col}, State,
	      Errors, TabWidth) ->
    case catch list_to_float(reverse(Stack)) of
      F when is_float(F) ->
	  scan(Cs, [], [{float, {Line, Col}, F} | Toks],
	       {Line, Col + length(Stack)}, State, Errors, TabWidth);
      _ ->
	  scan(Cs, [], Toks, {Line, Col}, State,
	       [{{illegal, float}, {Line, Col}} | Errors], TabWidth)
    end.

scan_exponent_sign([$+ | Cs], Stack, Toks, {Line, Col},
		   State, Errors, TabWidth) ->
    scan_exponent(Cs, [$+ | Stack], Toks, {Line, Col},
		  State, Errors, TabWidth);
scan_exponent_sign([$- | Cs], Stack, Toks, {Line, Col},
		   State, Errors, TabWidth) ->
    scan_exponent(Cs, [$- | Stack], Toks, {Line, Col},
		  State, Errors, TabWidth);
scan_exponent_sign([], Stack, Toks, {Line, Col}, State,
		   Errors, TabWidth) ->
    more([], Stack, Toks, {Line, Col}, State, Errors, TabWidth,
	 fun scan_exponent_sign/7);
scan_exponent_sign(Cs, Stack, Toks, {Line, Col}, State,
		   Errors, TabWidth) ->
    scan_exponent(Cs, Stack, Toks, {Line, Col}, State,
		  Errors, TabWidth).

scan_exponent([C | Cs], Stack, Toks, {Line, Col}, State,
	      Errors, TabWidth)
    when C >= $0, C =< $9 ->
    scan_exponent(Cs, [C | Stack], Toks, {Line, Col}, State,
		  Errors, TabWidth);
scan_exponent([], Stack, Toks, {Line, Col}, State,
	      Errors, TabWidth) ->
    more([], Stack, Toks, {Line, Col}, State, Errors,TabWidth,
	 fun scan_exponent/7);
scan_exponent(Cs, Stack, Toks, {Line, Col}, State,
	      Errors, TabWidth) ->
    case catch list_to_float(reverse(Stack)) of
      F when is_float(F) ->
	  scan(Cs, [], [{float, {Line, Col}, F} | Toks],
	       {Line, Col + length(Stack)}, State, Errors, TabWidth);
      _ ->
	  scan(Cs, [], Toks, {Line, Col}, State,
	       [{{illegal, float}, {Line, Col}} | Errors], TabWidth)
    end.

scan_comment([$\n | Cs], Stack, Toks, {Line, _Col},
	     State, Errors, TabWidth) ->
    [StartPos|S] = reverse([$\n|Stack]),
    scan(Cs, [], [{comment, StartPos, S}|Toks], {Line + 1, 1}, State, Errors, TabWidth);
scan_comment([C | Cs], Stack, Toks, {Line, Col}, State,
	     Errors, TabWidth) ->
    scan_comment(Cs, [C|Stack], Toks, {Line, Col + 1}, State,
		 Errors, TabWidth);
scan_comment([], Stack, Toks, {Line, Col}, State,
	     Errors, TabWidth) ->
    more([], Stack, Toks, {Line, Col}, State, Errors,TabWidth,
	 fun scan_comment/7);
scan_comment(Eof, Stack, Toks, {Line, Col}, State,
	     Errors, TabWidth) ->
    [StartPos|S] = reverse(Stack),
    done(Eof, Errors, [{comment, StartPos, S}|Toks], {Line, Col}, State, TabWidth).

scan_dot([$% | _] = Cs, _Stack, Toks, {Line, Col},
	 State, Errors, TabWidth) ->
    done(Cs, Errors, [{dot, {Line, Col}} | Toks],
	 {Line, Col + 1}, State, TabWidth);
scan_dot([$\n | Cs], _Stack, Toks, {Line, Col}, State,
	 Errors, TabWidth) ->
    done(Cs, Errors, [{whitespace, {Line, Col+1}, '\n'}, {dot, {Line, Col}} | Toks],
	 {Line + 1, 1}, State, TabWidth);
scan_dot([C | Cs], _Stack, Toks, {Line, Col}, State,
	 Errors, TabWidth)
    when C >= $\000, C =< $\s ->
    done(Cs, Errors, [{dot, {Line, Col}} | Toks],
	 {Line, Col + 1}, State, TabWidth);
scan_dot([C | Cs], _Stack, Toks, {Line, Col}, State,
	 Errors, TabWidth)
    when C >= $\200, C =< $\240 ->
    done(Cs, Errors, [{dot, {Line, Col}} | Toks],
	 {Line, Col + 1}, State, TabWidth);
scan_dot([], Stack, Toks, {Line, Col}, State, Errors, TabWidth) ->
    more([], Stack, Toks, {Line, Col}, State, Errors,TabWidth,
	 fun scan_dot/7);
scan_dot(eof, _Stack, Toks, {Line, Col}, State,
	 Errors, TabWidth) ->
    done(eof, Errors, [{dot, {Line, Col}} | Toks],
	 {Line, Col}, State, TabWidth);
scan_dot(Cs, Stack, Toks, {Line, Col}, State, Errors, TabWidth) ->
    scan(Cs, Stack, [{'.', {Line, Col}} | Toks],
	 {Line, Col + 1}, State, Errors, TabWidth).

%% reserved_word(Atom) -> Bool
%%   return 'true' if Atom is an Erlang reserved word, else 'false'.

reserved_word('after') -> true;
reserved_word('begin') -> true;
reserved_word('case') -> true;
reserved_word('try') ->
    Opts = get_compiler_options(),
    not member(disable_try, Opts);
reserved_word('cond') ->
    Opts = get_compiler_options(),
    not member(disable_cond, Opts);
reserved_word('catch') -> true;
reserved_word('andalso') -> true;
reserved_word('orelse') -> true;
reserved_word('end') -> true;
reserved_word('fun') -> true;
reserved_word('if') -> true;
reserved_word('let') -> true;
reserved_word('of') -> true;
reserved_word('query') -> true;
reserved_word('receive') -> true;
reserved_word('when') -> true;
reserved_word('bnot') -> true;
reserved_word('not') -> true;
reserved_word('div') -> true;
reserved_word('rem') -> true;
reserved_word('band') -> true;
reserved_word('and') -> true;
reserved_word('bor') -> true;
reserved_word('bxor') -> true;
reserved_word('bsl') -> true;
reserved_word('bsr') -> true;
reserved_word('or') -> true;
reserved_word('xor') -> true;
reserved_word('spec') -> true;
reserved_word(_) -> false.

get_compiler_options() ->
    %% Who said that Erlang has no global variables?
    case get(compiler_options) of
      undefined ->
	  Opts = case catch ets:lookup(compiler__tab,
				       compiler_options)
		     of
		   [{compiler_options, O}] -> O;
		   _ -> []
		 end,
	  put(compiler_options, Opts),
	  Opts;
      Opts -> Opts
    end.