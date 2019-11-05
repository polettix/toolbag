#!/bin/sh

die() { log "$*" ; exit 1 ; }
log() { printf >&2 %s\\n "$*" ; }

jq_get() { printf %s "$json" | jq -r "$*" ; }
jq_tget() { printf %s "$json" | jq -r ".tools[$i] | $*" ; }
filter_string() {
   sed -e "s/\(^\|[^%]\)%T/\1$(date +'%Y%m%d%H%M')/g;s/%%/%/g"
}

main() {
   set -eu

   local optname optval
   local clone=0
   while [ $# -gt 0 ] ; do
      optname="$1"
      shift
      case "$optname" in
         (-c|--clone)
            clone=1
            ;;
         (-i|--input)
            [ $# -gt 0 ] || die "no option for <$optname>"
            exec < "$1"
            shift
            ;;
         (*)
            die "unknown option <$optname>"
            ;;
      esac
   done
   toolbag
}

toolbag() {
   local json="$(cat -)" # save for reuse
   local target="$(jq_get .target | filter_string)"
   local targetar="$target.tar.gz"
   local tmpdir="$(mktemp -d -p "$PWD")"
   local workdir="$tmpdir/$target"
   mkdir -p "$workdir"

   local n="$(jq_get '.tools | length')"
   local i=0
   local cmd
   while [ $i -lt $n ] ; do
      local type="$(jq_tget .type)"
      cmd=''
      case "$type" in
         (dir)
            add_dir
            ;;
         (file)
            cmd=_cp
            add_stuff
            ;;
         (git)
            add_git
            ;;
         (tar)
            cmd=_tar
            add_stuff
            ;;
         (*)
            log "unhandled tool type <$type>, skipping"
            ;;
      esac
      i=$((i + 1))
   done

   printf %s\\n "$json" > "$workdir/toolbag-config.json"

   tar czf "$targetar" -C "$tmpdir" "$target"
   rm -rf "$tmpdir"
   printf %s\\n "$PWD/$targetar"
}

_cp() { cp "$1" "$2" ; }
_tar() { tar xf "$1" -C "$2" ; }

save_hash() { printf %s\\n "$*" >> "$workdir/toolbag-hashes.txt" ; }

add_dir() {
   local dirname="$(jq_tget '.dir // empty')"
   log "adding $type $dirname"

   local prefix="$(jq_tget '.prefix // "."')"
   local tdir="$workdir/$prefix"
   mkdir -p "$tdir"
   tar cC "$dirname" . | tar xC "$tdir"

   save_hash "*:*" "$prefix" "$dirname"
}

add_stuff() {
   local url="$(jq_tget '.url // empty')"
   local filename="$(jq_tget '.file // empty')"
   local origin="$filename"
   if [ -n "$url" ] ; then
      origin="$url"
      filename="$tmpdir/${filename:-"${url##*/}"}"
      wget -O "$filename" "$url"
   fi
   log "adding $type $origin"

   local prefix="$(jq_tget '.prefix // "."')"
   local tdir="$workdir/$prefix"
   mkdir -p "$tdir"
   "$cmd" "$filename" "$tdir"

   local hash="$(md5sum "$filename" | awk '{print $1}')"
   save_hash "md5:$hash" "$prefix" "$origin"
}

add_git() {
   local url="$(jq_tget '.url // empty')"
   local ref="$(jq_tget '.ref // "remotes/origin/master"')"
   log "adding $type $url#$ref"

   local repodir="$(jq_tget '.repodir // empty')"
   repodir="${repodir:-"${url##*/}"}"
   [ $clone -eq 0 ] || repodir="$tmpdir/$repodir"
   if [ -d "$repodir" ] ; then
      (
         cd "$repodir"
         git fetch
      )
   else
      git clone "$url" "$repodir"
   fi

   local hash="$(cd "$repodir" && git rev-parse "$ref")"

   local prefix="$(jq_tget '.prefix // "."')"
   local tdir="$workdir/$prefix"
   mkdir -p "$tdir"
   (cd "$repodir" && git archive --format tar "$hash") | tar xC "$tdir"

   save_hash "sha1:$hash" "$prefix" "$url"
}

main "$@"
