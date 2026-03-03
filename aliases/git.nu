export alias ga = git add
export alias gaa = git add --all
export alias gap = git add --patch
export alias gac = git commit --verbose --all

export alias gam = git commit --amend --no-edit

export alias gb = git branch
export alias gba = git branch --all
export alias gbl = git blame -b -w

export alias gc = git commit --verbose
export alias gc! = git commit --verbose --amend
export alias gcn = git commit --verbose --no-edit
export alias gcn! = git commit --verbose --no-edit --amend
export alias gca = git commit --verbose --all
export alias gca! = git commit --verbose --all --amend
export alias gcan! = git commit --verbose --all --no-edit --amend

export alias gcb = git checkout -b
export alias gcl = git clone --recurse-submodules
export alias gco = git checkout --recurse-submodules

export alias gsw = git switch
export alias gswc = git switch --create
export alias gsw! = git switch --create

export alias gcp = git cherry-pick
export alias gcpa = git cherry-pick --abort
export alias gcpc = git cherry-pick --continue

export alias gd = git diff
export alias gds = git diff --staged

export alias gf = git fetch --all --prune

export alias gg = ^lazygit

export alias gl = ^git log --all --color=always --pretty=format:"%C(yellow)%h%C(reset) %C(green)%ad%C(reset) %s %C(blue)(%an)%C(reset) %H" --date=format:"%Y-%m-%d %I:%M %p"
export alias gtoday = git log --since='midnight' --oneline $"--author=(git config get 'user.name')"

export alias gm = git merge -X ignore-cr-at-eol

export alias gmt = git mergetool
export alias gma = git merge --abort

export alias gp = git push
export alias gpf = git push --force-with-lease
export alias gpf! = git push --force
export alias gpl = git pull

export alias grb = git rebase --interactive

export alias grm = git rm
export alias grmc = git rm --cached

export alias grs = git restore

export alias gs = git status --short --branch
export alias gsh = git show

export alias gbs = git bisect
export alias gbsb = git bisect bad
export alias gbsg = git bisect good
export alias gbsn = git bisect new
export alias gbso = git bisect old
export alias gbsr = git bisect reset
export alias gbss = git bisect start