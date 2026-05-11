if exists("b:current_syntax")
  finish
endif
scriptencoding utf-8

syn sync fromstart
syn spell notoplevel

syn include @jiejieDiff syntax/diff.vim

" syn region jiejieHeadSection start=/^[A-Za-z ]\+:/ end=/^$/ fold
" syn match jiejieHeader /^[A-Za-z@ ]\+:/ contained containedin=jiejieHeadSection nextgroup=jiejieHeaderMapping skipwhite
" syn match jiejieHeaderMapping /\S\+/ contained nextgroup=jiejieHeaderValue
" syn match jiejieHeaderValue /[^†]*/ contained nextgroup=jiejieHeaderValueEmphasis
" syn match jiejieHeaderValueEmphasis /†/ contained conceal nextgroup=jiejieHeaderValueEmphasized
" syn match jiejieHeaderValueEmphasized /[^‡]\+/ contained nextgroup=jiejieHeaderValueReset
" syn match jiejieHeaderValueReset /‡/ contained conceal nextgroup=jiejieHeaderValue

syn region jiejieLineOne start=/^\%(\%1l\)\@=/ end=/\%(\%1l\)$/ keepend
syn match jiejieOperationId /[a-z0-9]\+/ contained containedin=jiejieLineOne nextgroup=jiejieAuthorEmail skipwhite
syn match jiejieAuthorEmail /[^ ]\+/ contained nextgroup=jiejieDuration skipwhite
syn match jiejieDuration /.\+$/ contained
hi def link jiejieLineOne Identifier

" syn match jiejieLineTwo /^\%2l*$/
" hi def link jiejieLineTwo Normal

syn match jiejieElided /^\~  .*$/

syn region jiejieChangeSection start=/^\%( \?[╭╮├┤╰─╯│] \?\)*[@×◆○]\%( \?[╭╮├┤╰─╯│] \?\)*  \+/ end=/^\%(\%( \?[╭╮├┤╰─╯│] \?\)*[@×◆○]\)\@=/ fold
" syn match jiejieChangeGraph /\%( \?[╭╮├┤╰─╯│] \?\)*  \+/ contained nextgroup=jiejieOperationId,jiejieArgs skipwhite
" syn match jiejieChangeGraphHead /^\%( \?[╭╮├┤╰─╯│] \?\)*/ contained containedin=jiejieChangeSection nextgroup=jiejieChangeStatusMutable,jiejieChangeStatusCurrent,jiejieChangeStatusConflict,jiejieChangeStatusImmutable
" syn match jiejieChangeStatusMutable /○/ contained nextgroup=jiejieChangeGraph skipwhite
" syn match jiejieChangeStatusCurrent /@/ contained nextgroup=jiejieChangeGraph skipwhite
" syn match jiejieChangeStatusConflict /×/ contained nextgroup=jiejieChangeGraph skipwhite
" syn match jiejieChangeStatusImmutable /◆/ contained nextgroup=jiejieChangeGraph skipwhite

syn match jiejieArgs /^args: / nextgroup=jiejieArgument
syn match jiejieArgument /.\+$/ contained

syn match jiejieChange /^\%(\%( \?[╭╮├┤╰─╯│ ] \?\)*\|[@×◆○] \+\)\%([-+] \)\@=/ nextgroup=jiejieChangeDelete,jiejieChangeAdd containedin=jiejieChangeSection
syn match jiejieChangeDelete /-/ contained nextgroup=jiejieChangeIdShort skipwhite
syn match jiejieChangeAdd /+/ contained nextgroup=jiejieChangeIdShort skipwhite
syn match jiejieChangeIdShort /[a-z0-9]\+\(\/[0-9]\+\)\?/ contained nextgroup=jiejieCommitId skipwhite
syn match jiejieCommitId /[a-z0-9]\+/ contained nextgroup=jiejieChangeHidden,jiejieChangeEmpty,jiejieChangeStatusConflict,jiejieChangeMessageEmpty,jiejieChangeMessage skipwhite
syn match jiejieChangeHidden /hidden/ contained nextgroup=jiejieChangeEmpty,jiejieChangeStatusConflict,jiejieChangeMessageEmpty,jiejieChangeMessage skipwhite
syn match jiejieChangeEmpty /(empty)/ contained nextgroup=jiejieChangeStatusConflict,jiejieChangeMessageEmpty,jiejieChangeMessage skipwhite
syn match jiejieChangeStatusConflict /(conflict)/ contained nextgroup=jiejieChangeMessageEmpty,jiejieChangeMessage skipwhite
syn match jiejieChangeMessageEmpty /(no description set)/ contained
syn match jiejieChangeMessage /.\+/ contained

syn region jiejieFileSection start=/^[╭╮├┤╰─╯│ ]\%( \?[╭╮├┤╰─╯│] \?\)*  \+[MADRC] / end=/^\%(^[^ ]\)\@=/  containedin=jiejieChangeSection  fold
syn match jiejieFileGraph /^[╭╮├┤╰─╯│ ]\%( \?[╭╮├┤╰─╯│] \?\)*  \+\%([MADRC] \)\@=/ contained containedin=jiejieFileSection nextgroup=jiejieFileModified,jiejieFileDeleted,jiejieFileAdded,jiejieFileRenamed,jiejieFileCopied
syn match jiejieFileModified /M/ contained nextgroup=jiejieFilename skipwhite
syn match jiejieFileDeleted /D/ contained nextgroup=jiejieFilename skipwhite
syn match jiejieFileAdded /A/ contained nextgroup=jiejieFilename skipwhite
syn match jiejieFileRenamed /R/ contained nextgroup=jiejieFilename skipwhite
syn match jiejieFileCopied /C/ contained nextgroup=jiejieFilename skipwhite
syn match jiejieFilename /.\+$/ contained nextgroup=jiejieHunkSection skipnl
syn region jiejieHunkSection start=/^ *\%(@@\+ -\|Binary files \|+++ \|--- \|diff \)\@=/ end=/^\%(^[^ ]\)\@=/ contained
syn match jiejieDiff /^   / contained containedin=jiejieHunkSection nextgroup=jiejieDiffAdded,jiejieDiffChanged,jiejieDiffFile,jiejieDiffIndexLine,jiejieDiffLine,jiejieDiffNewFilejiejieDiffOldFile,jiejieDiffRemoved,

" INFO: due to all diff syntax matches starting with `^`, they had to be forced to make them work here
syn match jiejieDiffIndexLine	"index \x\x\x\x.*" contained
syn match jiejieDiffSubname	"@@..*"ms=s+3 contained
syn match jiejieDiffLine	"@.*" contains=jiejieDiffSubname contained
syn match jiejieDiffLine	"\<\d\+\>.*" contained
syn match jiejieDiffLine	"\*\*\*\*.*" contained
syn match jiejieDiffLine	"---$" contained
syn match jiejieDiffLine	"\d\+\(,\d\+\)\=[cda]\d\+\>.*" contained
syn match jiejieDiffFile	"diff\>.*" contained
syn match jiejieDiffFile	"Index: .*" contained
syn match jiejieDiffFile	"==== .*" contained
syn match jiejieDiffRemoved	"-.*" contained
syn match jiejieDiffRemoved	"<.*" contained
syn match jiejieDiffAdded	"+.*" contained
syn match jiejieDiffAdded	">.*" contained
syn match jiejieDiffChanged	"! .*" contained
syn match jiejieDiffOldFile	"--- .*" contained
syn match jiejieDiffNewFile	"+++ .*" contained

hi def link jiejieDiffOldFile diffOldFile
hi def link jiejieDiffNewFile diffNewFile
hi def link jiejieDiffIndexLine diffIndexLine
hi def link jiejieDiffFile diffFile
hi def link jiejieDiffOnly diffOnly
hi def link jiejieDiffIdentical diffIdentical
hi def link jiejieDiffDiffer diffDiffer
hi def link jiejieDiffBDiffer diffBDiffer
hi def link jiejieDiffIsA diffIsA
hi def link jiejieDiffNoEOL diffNoEOL
hi def link jiejieDiffCommon diffCommon
hi def link jiejieDiffRemoved diffRemoved
hi def link jiejieDiffChanged diffChanged
hi def link jiejieDiffAdded diffAdded
hi def link jiejieDiffLine diffLine
hi def link jiejieDiffSubname diffSubname
hi def link jiejieDiffComment diffComment

hi def link jiejieHeader Identifier
hi def link jiejieHeaderMapping Special
hi def link jiejieHeaderValue Comment
hi def link jiejieHeaderValueEmphasized Debug

hi def link jiejieChangeStatusConflict Error
hi def link jiejieChangeStatusCurrent Todo
hi def link jiejieChangeStatusMutable Normal

hi def link jiejieChangeAdd Added
hi def link jiejieChangeDelete Removed
hi def link jiejieChangeId Identifier
hi def link jiejieCommitId Keyword
hi def link jiejieOperationId Macro
hi def link jiejieAuthorEmail Special
hi def link jiejieDuration NonText
hi def link jiejieArgument TypeDef

hi def link jiejieArgs NonText
hi def link jiejieChangeHidden NonText
hi def link jiejieElided NonText

hi def link jiejieFileModified Type
hi def link jiejieFileDeleted Type
hi def link jiejieFileAdded Type
hi def link jiejieFileRenamed Type
hi def link jiejieFileCopied Type

let b:current_syntax = "jiejie_opchange"
