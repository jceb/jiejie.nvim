if exists("b:current_syntax")
  finish
endif

syn sync fromstart
syn spell notoplevel

syn include @jiejieDiff syntax/diff.vim

syn region jiejieCommit start=/^[─╯│ ]*[@×◆○]  / end=/$/ fold
syn match jiejieCommitStatusNormal /^[─╯│ ]*\zs○/ contained containedin=jiejieCommit nextgroup=jiejieHash skipwhite
syn match jiejieCommitStatusCurrent /^[─╯│ ]*\zs@/ contained containedin=jiejieCommit nextgroup=jiejieHash skipwhite
syn match jiejieCommitStatusConflict /^[─╯│ ]*\zs×/ contained containedin=jiejieCommit nextgroup=jiejieHash skipwhite
syn match jiejieCommitStatusRoot /^[─╯│ ]*\zs◆/ contained containedin=jiejieCommit nextgroup=jiejieHash skipwhite

syn match jiejieEmptyCommitSeparator /†/ contained conceal nextgroup=jiejieCommitEmpty
syn match jiejieMessageSeparator /‡/ contained conceal nextgroup=jiejieCommitMessageEmpty,jiejieCommitMessage
syn match jiejieBookmarkSeparator /⌠/ contained conceal nextgroup=jiejieBookmark
syn match jiejieTagSeparator /⌡/ contained conceal nextgroup=jiejieTag
syn match jiejieGitHeadSeparator /∬/ contained conceal nextgroup=jiejieGitHead

syn match jiejieHash /[a-z]\+\ze\t/ contained nextgroup=jiejieEmptyCommitSeparator,jiejieMessageSeparator skipwhite
syn match jiejieCommitEmpty /(empty) / contained nextgroup=jiejieMessageSeparator
syn match jiejieCommitMessage /[^⌠]*/ contained nextgroup=jiejieBookmarkSeparator
syn match jiejieCommitMessageEmpty /(no description set)/ contained nextgroup=jiejieBookmarkSeparator
syn match jiejieBookmark /[^⌡]*/ contained nextgroup=jiejieTagSeparator
syn match jiejieTag /[^∬]*/ contained nextgroup=jiejieGitHeadSeparator
syn match jiejieGitHead /\( git_head()\)\?/ contained
" syn match jiejieFiles /$/ contained

syn match jiejieElided /^\~  .*$/

hi def link jiejieCommitEmpty String
hi def link jiejieCommitMessage Normal
hi def link jiejieCommitMessageEmpty String
hi def link jiejieCommitStatusConflict Error
hi def link jiejieCommitStatusCurrent Todo
hi def link jiejieCommitStatusNormal Normal
hi def link jiejieCommitStatusRoot Typedef
hi def link jiejieElided NonText
hi def link jiejieGitHead Include
hi def link jiejieHash Identifier
hi def link jiejieBookmark Constant
hi def link jiejieTag Tag

syn region jiejieHunk start=/^\%(@@\+ -\)\@=/ end=/^\%([A-Za-z?@]\|$\)\@=/ contains=diffLine,diffRemoved,diffAdded,diffNoEOL containedin=@jiejieSection fold

" Debugging
" hi def link jiejieEmptyMessageSeparator Error
" hi def link jiejieMessageSeparator Todo
" hi def link jiejieTagSeparator Typedef
" hi def link jiejieGitHeadSeparator NonText

let b:current_syntax = "jiejie"
