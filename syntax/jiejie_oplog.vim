if exists("b:current_syntax")
  finish
endif
scriptencoding utf-8

syn sync fromstart
syn spell notoplevel

" syn include @jiejieDiff syntax/diff.vim

syn region jiejieHeadSection start=/^[A-Za-z ]\+:/ end=/^$/ fold
syn match jiejieHeader /^[A-Za-z ]\+:/ contained containedin=jiejieHeadSection nextgroup=jiejieHeaderMapping skipwhite
syn match jiejieHeaderMapping /[^ ]\+/ contained nextgroup=jiejieHeaderValue
syn match jiejieHeaderValue /[^†]*/ contained nextgroup=jiejieHeaderValueEmphasis
syn match jiejieHeaderValueEmphasis /†/ contained conceal nextgroup=jiejieHeaderValueEmphasized
syn match jiejieHeaderValueEmphasized /[^‡]\+/ contained nextgroup=jiejieHeaderValueReset
syn match jiejieHeaderValueReset /‡/ contained conceal nextgroup=jiejieHeaderValue

syn match jiejieElided /^\~  .*$/

syn region jiejieChangeSection start=/^\%( \?[╭╮├┤╰─╯│] \?\)*[@○]\%( \?[╭╮├┤╰─╯│] \?\)*  \+/ end=/^\%(\%( \?[╭╮├┤╰─╯│] \?\)*[@○]\)\@=/ fold
syn match jiejieChangeGraph /\%( \?[╭╮├┤╰─╯│] \?\)*  \+/ contained nextgroup=jiejieCommitId,jiejieArgs, skipwhite
syn match jiejieChangeGraphHead /^\%( \?[╭╮├┤╰─╯│] \?\)*/ contained containedin=jiejieChangeSection nextgroup=jiejieChangeStatusMutable,jiejieChangeStatusCurrent
syn match jiejieChangeStatusMutable /○/ contained nextgroup=jiejieChangeGraph
syn match jiejieChangeStatusCurrent /@/ contained nextgroup=jiejieChangeGraph
syn match jiejieCommitId /[a-z0-9]\+/ contained nextgroup=jiejieAuthorEmail skipwhite
syn match jiejieAuthorEmail /[^ ]\+/ contained nextgroup=jiejieDuration skipwhite
syn match jiejieDuration /.*$/ contained

syn match jiejieArgs /args: .*/ contained containedin=jiejieChangeSection

syn match jiejieChange / \%([-+] \)\@=/ contained containedin=jiejieChangeSection nextgroup=jiejieChangeDelete,jiejieChangeAdd
syn match jiejieChangeDelete /-/ contained nextgroup=jiejieChangeIdShort skipwhite
syn match jiejieChangeAdd /+/ contained nextgroup=jiejieChangeIdShort skipwhite
syn match jiejieChangeIdShort /[a-z]\+/ contained nextgroup=jiejieChangeHidden,jiejieChangeEmpty,jiejieChangeStatusConflict,jiejieChangeMessageEmpty,jiejieChangeMessage skipwhite
syn match jiejieChangeHidden /hidden/ contained nextgroup=jiejieChangeEmpty,jiejieChangeStatusConflict,jiejieChangeMessageEmpty,jiejieChangeMessage skipwhite
syn match jiejieChangeEmpty /(empty)/ contained nextgroup=jiejieChangeStatusConflict,jiejieChangeMessageEmpty,jiejieChangeMessage skipwhite
syn match jiejieChangeStatusConflict /(conflict)/ contained nextgroup=jiejieChangeMessageEmpty,jiejieChangeMessage skipwhite
syn match jiejieChangeMessageEmpty /(no description set)/ contained skipwhite
syn match jiejieChangeMessage /.*/ contained

syn region jiejieFileSection start=/^[╭╮├┤╰─╯│]\%( \?[╭╮├┤╰─╯│] \?\)*  \+[MADRC]/ end=/^\%([╭╮├┤╰─╯│@×◆○][^@]\)\@=/ containedin=jiejieChangeSection contained
syn match jiejieFileGraph /^[╭╮├┤╰─╯│]\%( \?[╭╮├┤╰─╯│] \?\)*  \+/ contained containedin=jiejieFileSection nextgroup=jiejieFileModified,jiejieFileDeleted,jiejieFileAdded,jiejieFileRenamed,jiejieFileCopied
syn match jiejieFileModified /M/ contained nextgroup=jiejieFilename skipwhite
syn match jiejieFileDeleted /D/ contained nextgroup=jiejieFilename skipwhite
syn match jiejieFileAdded /A/ contained nextgroup=jiejieFilename skipwhite
syn match jiejieFileRenamed /R/ contained nextgroup=jiejieFilename skipwhite
syn match jiejieFileCopied /C/ contained nextgroup=jiejieFilename skipwhite
syn match jiejieFilename /.*$/ contained nextgroup=jiejieHunkSection skipnl
" syn region jiejieHunkSection start=/^\%(@@\+ -\|Binary files \)\@=/ end=/^\%(\%([╭╮├┤╰─╯│@×◆◇○]\|\%( \?[╭╮├┤╰─╯│] \?\)*[@×◆◇○]\)\%( \?[╭╮├┤╰─╯│] \?\)*  \)\@=/ contains=diffLine,diffRemoved,diffAdded,diffNoEOL,diffBDiffer contained fold

hi def link jiejieChangeAdd DiffAdd
hi def link jiejieChangeDelete DiffDelete
hi def link jiejieCommitId Identifier
hi def link jiejieAuthorEmail Constant
hi def link jiejieDuration Special
hi def link jiejieArgs String

let b:current_syntax = "jiejie_oplog"
