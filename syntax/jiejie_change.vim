if exists("b:current_syntax")
  finish
endif
scriptencoding utf-8

syn sync fromstart
syn spell notoplevel

syn include @jiejieDiff syntax/diff.vim

syn region jiejieHeadSection start=/^[A-Za-z ]\+:/ end=/^$/ fold
syn match jiejieHeader /^[A-Za-z ]\+:/ contained containedin=jiejieHeadSection nextgroup=jiejieHeaderValue skipwhite
syn match jiejieHeaderValue /.\+/ contained

syn region jiejieFileSection start=/^\zs[MADRC] / end=/^\%(diff \)\@=/
syn match jiejieFileModified /^M/ contained containedin=jiejieFileSection nextgroup=jiejieFilename skipwhite
syn match jiejieFileDeleted /^D/ contained containedin=jiejieFileSection nextgroup=jiejieFilename skipwhite
syn match jiejieFileAdded /^A/ contained containedin=jiejieFileSection nextgroup=jiejieFilename skipwhite
syn match jiejieFileRenamed /^R/ contained containedin=jiejieFileSection nextgroup=jiejieFilename skipwhite
syn match jiejieFileCopied /^C/ contained containedin=jiejieFileSection nextgroup=jiejieFilename skipwhite
syn match jiejieFilename /.\+$/ contained

syn region jiejieHunkSection start=/^\%(diff \)\@=/ end=/^$/ contains=diffLine,diffRemoved,diffAdded,diffNoEOL,diffFile,diffIndexLine fold

hi def link jiejieHeader Identifier
hi def link jiejieHeaderMapping Special
hi def link jiejieHeaderValue Comment
hi def link jiejieHeaderValueEmphasized Debug

hi def link jiejieFileModified Type
hi def link jiejieFileDeleted Type
hi def link jiejieFileAdded Type
hi def link jiejieFileRenamed Type
hi def link jiejieFileCopied Type

let b:current_syntax = "jiejie_change"
