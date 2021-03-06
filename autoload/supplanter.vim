let s:MAX_COMMAND_ARGS = 3


function supplanter#Supplanter(argString) abort
    let l:supplanter = {
                \ 'argString': a:argString,
                \ 'grepCommand': 0,
                \ 'shouldReplaceMatches': 0,
                \ 'word': '',
                \ 'replacement': '',
                \ 'substituteFlags': '',
                \ 'isCaseSensitive': 1,
                \ 'shouldMatchFileExtension': 1,
                \ 'InitSupplanter': function('s:InitSupplanter'),
                \ 'ParseAndRemoveModifiers':
                    \ function('s:ParseAndRemoveModifiers'),
                \ 'HasModifiers': function('s:HasModifiers'),
                \ 'ParseModifiers': function('s:ParseModifiers'),
                \ 'RemoveModifiersFromArgString':
                    \ function('s:RemoveModifiersFromArgString'),
                \ 'ParseArgs': function('s:ParseArgs'),
                \ 'ValidateArgs': function('s:ValidateArgs'),
                \ 'InitGrepCommand': function('s:InitGrepCommand'),
                \ 'HasReplacementParams': function('s:HasReplacementParams'),
                \ 'AddExcludeDirGlobs': function('s:AddExcludeDirGlobs'),
                \ 'AddExcludeGlobs': function('s:AddExcludeGlobs'),
                \ 'AddIncludeGlobs': function('s:AddIncludeGlobs'),
                \ 'FindAll': function('s:FindAll'),
                \ 'ReplaceAll': function('s:ReplaceAll'),
                \ 'GetLocListSubstituteCommand':
                    \ function('s:GetLocListSubstituteCommand'),
                \ 'DidFindMatches': function('s:DidFindMatches'),
                \ 'SlashIsDelimiter': function('s:SlashIsDelimiter'),
                \ 'RemoveEscapes': function('s:RemoveEscapes'),
                \ }
    call l:supplanter.InitSupplanter()
    return l:supplanter
endfunction


function s:InitSupplanter() dict abort
    call self.ParseAndRemoveModifiers()
    call self.ParseArgs()
    let self.shouldReplaceMatches = self.HasReplacementParams()
    let self.grepCommand = self.InitGrepCommand()
    call self.grepCommand.SetCaseSensitivity(self.isCaseSensitive)
    call self.grepCommand.SetLimitsResultsPerFile(self.HasReplacementParams())
endfunction


function s:ParseAndRemoveModifiers() dict abort
    if self.HasModifiers()
        call self.ParseModifiers()
        call self.RemoveModifiersFromArgString() 
    endif
endfunction


function s:HasModifiers() dict abort
    return len(split(self.argString, ' -')) > 1
endfunction


function s:ParseModifiers() dict abort
    let splitArgs = split(self.argString, ' -')
    let extraFlags = remove(splitArgs, 1, -1)
    for flag in extraFlags
        if match(flag, 'f') >= 0
            let self.shouldMatchFileExtension = 0
        endif
        if match(flag, 'i') >= 0
            let self.isCaseSensitive = 0
        endif
    endfor
endfunction


function s:RemoveModifiersFromArgString() dict abort
    let self.argString = split(self.argString, ' -')[0]
endfunction


function s:ParseArgs() dict abort
    call self.ValidateArgs()
    let destVars = ['word', 'replacement', 'substituteFlags']
    let argLen = len(self.argString)
    let [start, end] = [0, 1]
    while end < argLen
        if end == argLen - 1
            if self.argString[end] == '/'
                let lastCharIndex = self.SlashIsDelimiter(self.argString, end) ? end - 1: end
            else
                let lastCharIndex = end
            endif
            let self[remove(destVars, 0)] = self.RemoveEscapes(self.argString[start+1:lastCharIndex])
        elseif self.argString[end] == '/'
            if self.SlashIsDelimiter(self.argString, end)
                let self[remove(destVars, 0)] = self.RemoveEscapes(self.argString[start+1:end-1])
                let start = end
            endif
        endif
        let end += 1
    endwhile
endfunction


function s:ValidateArgs() dict abort
    if supplantUtils#GetFirstChar(self.argString) != '/'
        throw 'Supplanter: Invalid :substitute string'
    endif
endfunction


function s:SlashIsDelimiter(string, index) dict abort
    return !supplantUtils#CharIsEscaped(a:string, a:index)
endfunction


function s:RemoveEscapes(string) dict abort
    return substitute(a:string, '\(\\\)\([^\\]\)', '\2', 'g')
endfunction


function s:InitGrepCommand() dict abort
    let l:grepCommand = grepcommand#GrepCommand(self.word)
    return l:grepCommand
endfunction


function s:HasReplacementParams() dict abort
    return self.replacement != '' && self.substituteFlags != ''
endfunction


function s:AddExcludeGlobs(globs) dict abort
    if type(a:globs) != v:t_list
        throw 'AddExcludeGlobs expected type <v:t_list>'
    endif
    call self.grepCommand.AddNamedParameters('exclude', a:globs)
endfunction


function s:AddExcludeDirGlobs(globs) dict abort
    if type(a:globs) != v:t_list
        throw 'AddExcludeDirGlobs expected type <v:t_list>'
    endif
    call self.grepCommand.AddNamedParameters('exclude-dir', a:globs)
endfunction


function s:AddIncludeGlobs(globs) dict abort
    if type(a:globs) != v:t_list
        throw 'AddIncludeGlobs expected type <v:t_list>'
    endif
    call self.grepCommand.AddNamedParameters('include', a:globs)
endfunction


function s:FindAll() dict abort
    execute "lgetexpr system('" . self.grepCommand.ToString() . "')"
endfunction


function s:ReplaceAll() dict abort
    if !self.DidFindMatches()
        return
    endif
    execute self.GetLocListSubstituteCommand()
endfunction


function s:DidFindMatches() dict abort
    return len(getloclist(0)) > 0
endfunction


function s:GetLocListSubstituteCommand() dict abort
    return 'lfdo %s/\<' . self.word . '\>/' . self.replacement . '/' .
                \ self.substituteFlags
endfunction
