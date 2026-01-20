if exists("b:current_syntax")
  finish
endif
scriptencoding utf-8

syn sync fromstart
syn spell notoplevel

syn include @jiejieDiff syntax/diff.vim

syn region jiejieHead start=/^[A-Za-z]\+:/ end=/^$/ fold
syn match jiejieHeader /^[A-Za-z]\+:/ contained containedin=jiejieHead nextgroup=jiejieHeaderValue skipwhite
syn match jiejieHeaderValue /.\+/ contained

syn region jiejieChange start=/^[╮─╯│ ]*\zs[@×◆◇○]  / end=/$/ fold
syn match jiejieChangeStatusHead /○/ contained containedin=jiejieChange nextgroup=jiejieChangeIdShort skipwhite
syn match jiejieChangeStatusMutable /◇/ contained containedin=jiejieChange nextgroup=jiejieChangeIdShort skipwhite
syn match jiejieChangeStatusCurrent /@/ contained containedin=jiejieChange nextgroup=jiejieChangeIdShort skipwhite
syn match jiejieChangeStatusConflict /×/ contained containedin=jiejieChange nextgroup=jiejieChangeIdShort skipwhite
syn match jiejieChangeStatusImmutable /◆/ contained containedin=jiejieChange nextgroup=jiejieChangeIdShort skipwhite

syn region jiejieFiles start=/^[╮─╯│├ ]\+  \zs[MAD]/ end=/$/
syn match jiejieFileModified /M\ze / contained containedin=jiejieFiles nextgroup=jiejieFilename
syn match jiejieFileDeleted /D\ze / contained containedin=jiejieFiles nextgroup=jiejieFilename
syn match jiejieFileAdded /A\ze / contained containedin=jiejieFiles nextgroup=jiejieFilename
syn match jiejieFilename /.*/ contained

syn match jiejieEmptyChangeSeparator /†/ contained conceal nextgroup=jiejieChangeEmpty skipwhite
syn match jiejieMessageSeparator /‡/ contained conceal nextgroup=jiejieChangeMessageEmpty,jiejieChangeMessage skipwhite
syn match jiejieBookmarkSeparator /⌠/ contained conceal nextgroup=jiejieBookmark
syn match jiejieTagSeparator /⌡/ contained conceal nextgroup=jiejieTag
syn match jiejieGitHeadSeparator /∫/ contained conceal nextgroup=jiejieGitHead
syn match jiejieConflictSeparator /∬/ contained conceal nextgroup=jiejieConflict
syn match jiejieImmutableSeparator /∮/ contained conceal nextgroup=jiejieImmutable
syn match jiejieChangeIdSeparator /∴/ contained conceal nextgroup=jiejieChangeId

syn match jiejieChangeIdShort /[a-z]\+\t/ contained nextgroup=jiejieEmptyChangeSeparator
syn match jiejieChangeEmpty /\((empty) \)\?/ contained nextgroup=jiejieMessageSeparator
syn match jiejieChangeMessage /[^⌠]*/ contained nextgroup=jiejieBookmarkSeparator
syn match jiejieChangeMessageEmpty /(no description set)/ contained nextgroup=jiejieBookmarkSeparator
syn match jiejieBookmark /[^⌡]*/ contained nextgroup=jiejieTagSeparator
syn match jiejieTag /[^∫]*/ contained nextgroup=jiejieGitHeadSeparator
syn match jiejieGitHead /\( git_head()\)\?/ contained nextgroup=jiejieConflictSeparator
syn match jiejieConflict /\( conflict\)\?/ contained nextgroup=jiejieImmutableSeparator
syn match jiejieImmutable /\( immutable\)\?/ contained conceal nextgroup=jiejieChangeIdSeparator
syn match jiejieChangeId /.\+/ contained conceal


syn match jiejieElided /^\~  .*$/

hi def link jiejieHeader Identifier
hi def link jiejieHeaderValue Identifier

hi def link jiejieChangeEmpty String
hi def link jiejieChangeMessage Normal
hi def link jiejieChangeMessageEmpty String

hi def link jiejieChangeStatusConflict Error
hi def link jiejieChangeStatusCurrent Todo
hi def link jiejieChangeStatusMutable Normal
hi def link jiejieChangeStatusHead Search
hi def link jiejieChangeStatusImmutable Constant

hi def link jiejieFileModified Type
hi def link jiejieFileDeleted Type
hi def link jiejieFileAdded Type

hi def link jiejieElided NonText
hi def link jiejieGitHead Include
hi def link jiejieChangeIdShort Identifier
hi def link jiejieBookmark Constant
hi def link jiejieTag Tag
hi def link jiejieConflict Error

syn region jiejieHunk start=/^\%(@@\+ -\)\@=/ end=/^\%([A-Za-z?@]\|$\)\@=/ contains=diffLine,diffRemoved,diffAdded,diffNoEOL containedin=@jiejieSection fold

" " Debugging
" hi def link jiejieEmptyChangeSeparator Error
" hi def link jiejieEmptyMessageSeparator Error
" hi def link jiejieMessageSeparator Todo
" hi def link jiejieBookmarkSeparator Todo
" hi def link jiejieTagSeparator Typedef
" hi def link jiejieGitHeadSeparator NonText
" hi def link jiejieConflictSeparator NonText
" hi def link jiejieImmutableSeparator NonText
" hi def link jiejieChangeIdSeparator NonText

let b:current_syntax = "jiejie"
