if exists('g:loaded_mercurial') || &cp
  finish
endif

let g:loaded_mercurial = 1

function! s:Status() abort
  let command = expand('%b') =~ 'hg status' ? 'e' : 'split'
  execute command 'hg status'
    execute "resize 18"
    setlocal buftype=nofile
    setlocal syntax=diff
    syn match hgModified	"M .*$"
    syn match hgAdded	"A .*$"
    syn match hgMissing	"! .*$"
    syn match hgNew	"? .*$"
    syn match hgBranch	"(.*)$"
    hi hgModified guifg=#6699CC
    hi hgMissing guifg=#5FB3B3
    hi hgAdded guifg=#99C794
    hi hgNew guifg=#C595C5
    hi hgBranch guifg=#8C7A37
    let hg_branch = system('hg branch')[0:-2]
    let hg_status = system('hg status')
    let lines = ["On branch (".hg_branch.")",
              \ "",
              \ "Changes ready for commit: ",
              \ ""]
    let statuses = split(hg_status, '\n')
    for s in statuses
      let lines += ['    '.s]
    endfor
    normal ggdG
    call append(0, lines)
    nnoremap <silent> <buffer> <expr> - getline('.') =~ '    A' ? ":call system('hg forget '.getline('.')[6:-1]) \| HGstatus<CR>" : ""
    nnoremap <silent> <buffer> <expr> + getline('.') =~ '    ?' ? ":call system('hg add '.getline('.')[6:-1]) \| HGstatus<CR>" : ""
    nnoremap <silent> <buffer> D :call append(line('.'), split(system('hg diff '.getline('.')[6:-1]), '\n'))<CR>
endfunction

autocmd filetype * command! -buffer Hgstatus :exe s:Status()
