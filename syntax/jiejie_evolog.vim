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
syn match jiejieChangeGraph /\%( \?[╭╮├┤╰─╯│] \?\)*  \+/ contained nextgroup=jiejieChangeId skipwhite
syn match jiejieChangeGraphHead /^\%( \?[╭╮├┤╰─╯│] \?\)*/ contained containedin=jiejieChangeSection nextgroup=jiejieChangeStatusMutable,jiejieChangeStatusCurrent,jiejieChangeStatusConflict,jiejieChangeStatusImmutable,jiejieChangeMessageEmpty,jiejieOp skipwhite
syn match jiejieChangeStatusMutable /○/ contained nextgroup=jiejieChangeGraph skipwhite
syn match jiejieChangeStatusCurrent /@/ contained nextgroup=jiejieChangeGraph skipwhite
syn match jiejieChangeStatusConflict /×/ contained nextgroup=jiejieChangeGraph skipwhite
syn match jiejieChangeStatusImmutable /◆/ contained nextgroup=jiejieChangeGraph skipwhite
syn match jiejieChangeId /[a-z0-9]\+\(\/[0-9]\+\)\?/ contained nextgroup=jiejieAuthorEmail skipwhite
syn match jiejieAuthorEmail /\S\+/ contained nextgroup=jiejieDate skipwhite
syn match jiejieDate /[0-9-]\+ [0-9:]\+/ contained nextgroup=jiejieBookmark skipwhite
syn match jiejieBookmark /\( \S\+\)\?\ze [a-z0-9]\+/ contained nextgroup=jiejieCommitId skipwhite
syn match jiejieCommitId /[a-z0-9]\+/ contained nextgroup=jiejieChangeHidden skipwhite
syn match jiejieChangeHidden /\((hidden)\)\?$/ contained

syn match jiejieChangeMessageEmpty /\((empty) \)\?(no description set)$/ contained
syn match jiejieOp /-- operation/ contained nextgroup=jiejieOperationId skipwhite
syn match jiejieOperationId /[a-z0-9]\+/ contained nextgroup=jiejieOperation skipwhite
syn match jiejieOperation /.\+/ contained

syn region jiejieFileSection start=/^[╭╮├┤╰─╯│]\%( \?[╭╮├┤╰─╯│] \?\)*  \+[MADRC]/ end=/^\%([╭╮├┤╰─╯│@×◆○][^@]\)\@=/ containedin=jiejieChangeSection contained
syn match jiejieFileGraph /^[╭╮├┤╰─╯│]\%( \?[╭╮├┤╰─╯│] \?\)*  \+/ contained containedin=jiejieFileSection nextgroup=jiejieFileModified,jiejieFileDeleted,jiejieFileAdded,jiejieFileRenamed,jiejieFileCopied
syn match jiejieFileModified /M/ contained nextgroup=jiejieFilename skipwhite
syn match jiejieFileDeleted /D/ contained nextgroup=jiejieFilename skipwhite
syn match jiejieFileAdded /A/ contained nextgroup=jiejieFilename skipwhite
syn match jiejieFileRenamed /R/ contained nextgroup=jiejieFilename skipwhite
syn match jiejieFileCopied /C/ contained nextgroup=jiejieFilename skipwhite
syn match jiejieFilename /.\+$/ contained nextgroup=jiejieHunkSection skipnl
syn region jiejieHunkSection start=/^\%(@@\+ -\|Binary files \)\@=/ end=/^\%([╭╮├┤╰─╯│@×◆○][^@]\)\@=/ contains=diffLine,diffRemoved,diffAdded,diffNoEOL,diffBDiffer contained fold

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

hi def link jiejieChangeHidden NonText
hi def link jiejieElided NonText
hi def link jiejieOp NonText

hi def link jiejieDate Function
hi def link jiejieChangeId Identifier
hi def link jiejieCommitId Keyword
hi def link jiejieOperationId Macro
hi def link jiejieAuthorEmail Special
hi def link jiejieDate Special

let b:current_syntax = "jiejie_evolog"
