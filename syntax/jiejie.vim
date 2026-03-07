if exists("b:current_syntax")
  finish
endif
scriptencoding utf-8

syn sync fromstart
syn spell notoplevel

syn include @jiejieDiff syntax/diff.vim

syn region jiejieHeadSection start=/^[A-Za-z ]\+:/ end=/^$/ fold
syn match jiejieHeader /^[A-Za-z ]\+:/ contained containedin=jiejieHeadSection nextgroup=jiejieHeaderMapping skipwhite
syn match jiejieHeaderMapping /[^ ]\+/ contained nextgroup=jiejieHeaderValue
syn match jiejieHeaderValue /[^†]*/ contained nextgroup=jiejieHeaderValueEmphasis
syn match jiejieHeaderValueEmphasis /†/ contained conceal nextgroup=jiejieHeaderValueEmphasized
syn match jiejieHeaderValueEmphasized /[^‡]\+/ contained nextgroup=jiejieHeaderValueReset
syn match jiejieHeaderValueReset /‡/ contained conceal nextgroup=jiejieHeaderValue

syn match jiejieElided /^\~  .*$/

syn region jiejieChangeSection start=/^\%( \?[╭╮├┤╰─╯│] \?\)*[@×◆○]\%( \?[╭╮├┤╰─╯│] \?\)*  \+/ end=/^\%(\%( \?[╭╮├┤╰─╯│] \?\)*[@×◆○]\)\@=/ fold
syn match jiejieChangeGraph /\%( \?[╭╮├┤╰─╯│] \?\)*  \+/ contained nextgroup=jiejieChangeIdShort,jiejieChangeIdShortDivergent skipwhite
syn match jiejieChangeGraphHead /^\%( \?[╭╮├┤╰─╯│] \?\)*/ contained containedin=jiejieChangeSection nextgroup=jiejieChangeStatusHead,jiejieChangeStatusMutable,jiejieChangeStatusCurrent,jiejieChangeStatusConflict,jiejieChangeStatusImmutable
syn match jiejieChangeStatusMutable /○/ contained nextgroup=jiejieChangeGraph skipwhite
syn match jiejieChangeStatusCurrent /@/ contained nextgroup=jiejieChangeGraph skipwhite
syn match jiejieChangeStatusConflict /×/ contained nextgroup=jiejieChangeGraph skipwhite
syn match jiejieChangeStatusImmutable /◆/ contained nextgroup=jiejieChangeGraph skipwhite

syn region jiejieFileSection start=/^[╭╮├┤╰─╯│]\%( \?[╭╮├┤╰─╯│] \?\)*  \+[MADRC]/ end=/^\%([╭╮├┤╰─╯│@×◆○][^@]\)\@=/ containedin=jiejieChangeSection contained
syn match jiejieFileGraph /^[╭╮├┤╰─╯│]\%( \?[╭╮├┤╰─╯│] \?\)*  \+/ contained containedin=jiejieFileSection nextgroup=jiejieFileModified,jiejieFileDeleted,jiejieFileAdded,jiejieFileRenamed,jiejieFileCopied
syn match jiejieFileModified /M/ contained nextgroup=jiejieFilename skipwhite
syn match jiejieFileDeleted /D/ contained nextgroup=jiejieFilename skipwhite
syn match jiejieFileAdded /A\ze / contained nextgroup=jiejieFilename skipwhite
syn match jiejieFileRenamed /R/ contained nextgroup=jiejieFilename skipwhite
syn match jiejieFileCopied /C/ contained nextgroup=jiejieFilename skipwhite
syn match jiejieFilename /.*$/ contained nextgroup=jiejieHunkSection skipnl
syn region jiejieHunkSection start=/^\%(@@\+ -\|Binary files \)\@=/ end=/^\%([╭╮├┤╰─╯│@×◆○][^@]\)\@=/ contains=diffLine,diffRemoved,diffAdded,diffNoEOL,diffBDiffer contained fold

syn match jiejieEmptyChangeSeparator /†/ contained conceal nextgroup=jiejieChangeEmpty skipwhite
syn match jiejieMessageSeparator /‡/ contained conceal nextgroup=jiejieChangeMessageEmpty,jiejieChangeMessage skipwhite
syn match jiejieBookmarkSeparator /⌠/ contained conceal nextgroup=jiejieBookmark
syn match jiejieTagSeparator /⌡/ contained conceal nextgroup=jiejieTag
syn match jiejieGitHeadSeparator /∫/ contained conceal nextgroup=jiejieGitHead
syn match jiejieConflictSeparator /∬/ contained conceal nextgroup=jiejieConflict
syn match jiejieImmutableSeparator /∮/ contained conceal nextgroup=jiejieImmutable
syn match jiejieChangeIdSeparator /∴/ contained conceal nextgroup=jiejieChangeId
syn match jiejieAuthorEmailSeparator /∵/ contained conceal nextgroup=jiejieAuthorEmail
syn match jiejieDivergentSeparator /∶/ contained conceal nextgroup=jiejieDivergent
syn match jiejieCommitIdSeparator /∷/ contained conceal nextgroup=jiejieCommitId
syn match jiejieWorkingCopySeparator /∼/ contained conceal nextgroup=jiejieWorkingCopy
syn match jiejieParentsSeparator /∾/ contained conceal nextgroup=jiejieParents

syn match jiejieChangeIdShort /[a-z]\+\t/ contained nextgroup=jiejieEmptyChangeSeparator
syn match jiejieChangeIdShortDivergent /[a-z]\+??\t/ contained nextgroup=jiejieEmptyChangeSeparator
syn match jiejieChangeEmpty /\((empty) \)\?/ contained nextgroup=jiejieMessageSeparator
syn match jiejieChangeMessage /[^⌠]*/ contained nextgroup=jiejieBookmarkSeparator
syn match jiejieChangeMessageEmpty /(no description set)/ contained nextgroup=jiejieBookmarkSeparator
syn match jiejieBookmark /[^⌡]*/ contained nextgroup=jiejieTagSeparator
syn match jiejieTag /[^∫]*/ contained nextgroup=jiejieGitHeadSeparator
syn match jiejieGitHead /\( git_head()\)\?/ contained nextgroup=jiejieConflictSeparator
syn match jiejieConflict /\( conflict\)\?/ contained nextgroup=jiejieImmutableSeparator
syn match jiejieImmutable /\( immutable\)\?/ contained conceal nextgroup=jiejieChangeIdSeparator
syn match jiejieChangeId /[^∵]\+/ contained conceal nextgroup=jiejieAuthorEmailSeparator
syn match jiejieAuthorEmail /[^∶]\+/ contained nextgroup=jiejieDivergentSeparator
syn match jiejieDivergent /\( divergent\)\?/ contained conceal nextgroup=jiejieCommitIdSeparator
syn match jiejieCommitId /[a-z0-9]\+/ contained conceal nextgroup=jiejieWorkingCopySeparator
syn match jiejieWorkingCopy /\( current working copy\)\?/ contained conceal nextgroup=jiejieParentsSeparator
syn match jiejieParents /[0-9]\+/ contained conceal

hi def link jiejieHeader Identifier
hi def link jiejieHeaderMapping Special
hi def link jiejieHeaderValue Comment
hi def link jiejieHeaderValueEmphasized Debug

hi def link jiejieChangeEmpty String
hi def link jiejieChangeMessage Normal
hi def link jiejieChangeMessageEmpty String

hi def link jiejieChangeStatusConflict Error
hi def link jiejieChangeStatusCurrent Todo
hi def link jiejieChangeStatusMutable Normal
hi def link jiejieChangeStatusImmutable Constant

hi def link jiejieFileModified Type
hi def link jiejieFileDeleted Type
hi def link jiejieFileAdded Type
hi def link jiejieFileRenamed Type
hi def link jiejieFileCopied Type

hi def link jiejieElided NonText
hi def link jiejieGitHead Include
hi def link jiejieChangeIdShort Identifier
hi def link jiejieChangeIdShortDivergent Error
hi def link jiejieBookmark Constant
hi def link jiejieTag Tag
hi def link jiejieConflict Error
hi def link jiejieAuthorEmail Special

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
" hi def link jiejieAuthorEmailSeparator NonText

let b:current_syntax = "jiejie"
