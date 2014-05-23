#!/bin/bash

SVNDELIM="==================================================================="
EXPORT=false
LDPWRITERSVN="https://repo.dev.bbc.co.uk/services/linked-data/linked-data-writer/trunk/"
LDPCORESVN="https://repo.dev.bbc.co.uk/services/linked-data/linked-data-core-api/trunk"
LDPMANAGERSVN="https://repo.dev.bbc.co.uk/services/linked-data/linked-data-manager/trunk/"
LDPDIFFDIR="./ldpdiff"
LDPWRITER="WRITER"
LDPCORE="CORE"
LDPMANAGER="MANAGER"

function echo_help {
  echo "Usage:"
  echo "\tsh ldp-diff.sh ticketnumber [options]"
  echo ""
  echo "\tTo retrieve all relevant ldp-core and ldp-writer diffs, and write them to disk, for a code review of LINKEDDATA-xyz:"
  echo "\tsh ldp-diff.sh xyz -export"
  echo ""
  echo "Options:"
  echo "\t-help\t\tPrint this menu."
  echo ""
  echo "\t-export\t\tExport SVN diffs to ./diffs/ticketnumber"
}

function check_arguments {

  if [ ${#@} == 0 ]; then
    echo "Must provide a ticket number."
    exit 1
  elif [ ${#@} == 1 ]; then
    if echo $@ | grep -q -- '-help'; then
      echo_help
      exit
    fi
    TICKET=$1
  elif [ ${#@} > 1  ]; then
    TICKET=$1
    if echo $@ | grep -q -- '-export'; then
      EXPORT=true
    fi
  fi
}

function setUp {
  rm -rf "$LDPDIFFDIR"
  mkdir "$LDPDIFFDIR"
  if $EXPORT; then
    if [ -d "./diffs/$TICKET" ]; then
      rm -rf "./diffs/$TICKET"
    elif [ ! -d "./diffs" ]; then
      mkdir ./diffs
    fi
    mkdir "./diffs/$TICKET"
  fi
}

function cleanUp {
  rm -rf "$LDPDIFFDIR"
  if ! $EXPORT; then
    if [ -d "./diffs/$TICKET" ]; then
      rm -rf "./diffs/$TICKET"
    fi
  fi
}

function retrieveSvnLog {
  WRITERLOG=`svn log $LDPWRITERSVN`
  CORELOG=`svn log $LDPCORESVN`
  MANAGERLOG=`svn log $LDPMANAGERSVN`
}

function writeTicketRevisions {
  echo $WRITERLOG | sed 's/\- r/\-\
r/g' | grep "\[LINKEDDATA\-$TICKET\]" | sed 's/r\([0-9]*\) \|.*/\1/g' > $LDPDIFFDIR/ldpwriterlog.txt

  echo $CORELOG | sed 's/\- r/\-\
r/g' | grep "\[LINKEDDATA\-$TICKET\]" | sed 's/r\([0-9]*\) \|.*/\1/g' > $LDPDIFFDIR/ldpcorelog.txt

  echo $MANAGERLOG | sed 's/\- r/\-\
r/g' | grep "\[LINKEDDATA\-$TICKET\]" | sed 's/r\([0-9]*\) \|.*/\1/g' > $LDPDIFFDIR/ldpmanagerlog.txt
}

#
# $1 Name of file with revisions relevant to ticket to inspect
# $2 Name of file to write diff revisions to
# $3 Name of project being diffed
#
function writeDiffRevisions {
  if [ "$3" == "$LDPWRITER" ]; then
    local log=$WRITERLOG
  elif [ "$3" == "$LDPCORE" ]; then
    local log=$CORELOG
  elif [ "$3" == "$LDPMANAGER" ]; then
    local log=$MANAGERLOG
  else
    echo "Invalid project"
    exit
  fi

  local logLines=`sed -n '$=' $LDPDIFFDIR/$1`
  local c=1

  for ((c; c<=$logLines; c++))
  do
    local revision=`sed -n "$c"p $LDPDIFFDIR/$1`
    local previous=$(echo $log | sed "s/.*r$revision/r$revision/" | sed 's/\- r/\-\
r/g' | sed 's/r\([0-9]*\) \|.*/\1/g' | sed "/$revision/d" | sed -n 1p)
    echo $previous:$revision >> $LDPDIFFDIR/$2
  done
}

#
# $1 Revision numbers being diffed
# $2 Diff number
# $3 Name of project being diffed
#
function echoDiffMessage {
  echo $SVNDELIM
  echo "LDP-$3 DIFF $2: revisions $1"
  echo $SVNDELIM
}

#
# $1 Name of file with diff revisions to inspect
# $2 Name of project being diffed
#
function createDiffs {
  if [ "$2" == "$LDPWRITER" ]; then
    local repo=$LDPWRITERSVN
  elif [ "$2" == "$LDPCORE" ]; then
    local repo=$LDPCORESVN
  elif [ "$2" == "$LDPMANAGER" ]; then
    local repo=$LDPMANAGERSVN
  else
    echo "Invalid project"
    exit
  fi
  local revisionsLines=`sed -n '$=' $LDPDIFFDIR/$1`
  local c=$revisionsLines
  local diffc=1

  for (( diffc, c; c>=1; c--, diffc++ )); do
    local revisions=`sed -n "$c"p $LDPDIFFDIR/$1`
    echoDiffMessage $revisions $diffc $2

    local diff=`svn diff -r "$revisions" $repo`
    echo "$diff"
    if $EXPORT; then
      echo "$diff" > ./diffs/$TICKET/$TICKET-$2-$diffc.diff
    fi
  done
}

check_arguments $@
setUp

echo $SVNDELIM
echo "Retrieving SVN log for LINKEDDATA-$TICKET..."

retrieveSvnLog
writeTicketRevisions

catwriterlog=`cat $LDPDIFFDIR/ldpwriterlog.txt`
catcorelog=`cat $LDPDIFFDIR/ldpcorelog.txt`
catmanagerlog=`cat $LDPDIFFDIR/ldpmanagerlog.txt`

if [ -z "$catwriterlog" ] && [ -z "$catcorelog" ] && [ -z "$catmanagerlog" ]; then
  echo "No commits found in ldp-writer, ldp-core or ldp-manager for LINKEDDATA-$TICKET"
  exit
fi

if [ ! -z "$catwriterlog" ]; then
  echo $SVNDELIM
  echo "Found ldp-writer commits for LINKEDDATA-$TICKET"
  writeDiffRevisions "ldpwriterlog.txt" "ldpwriterrevisions.txt" $LDPWRITER
  createDiffs "ldpwriterrevisions.txt" $LDPWRITER
fi

if [ ! -z "$catcorelog" ]; then
  echo $SVNDELIM
  echo "Found ldp-core commits for LINKEDDATA-$TICKET"
  writeDiffRevisions "ldpcorelog.txt" "ldpcorerevisions.txt" $LDPCORE
  createDiffs "ldpcorerevisions.txt" $LDPCORE
fi

if [ ! -z "$catmanagerlog" ]; then
  echo $SVNDELIM
  echo "Found ldp-manager commits for LINKEDDATA-$TICKET"
  writeDiffRevisions "ldpmanagerlog.txt" "ldpmanagerrevisions.txt" $LDPMANAGER
  createDiffs "ldpmanagerrevisions.txt" $LDPMANAGER
fi

if $EXPORT; then
    echo $SVNDELIM
    echo "Diffs for each commit on this ticket can now be found at ./diffs/$TICKET/$TICKET-WRITER|CORE-n.diff"
    echo $SVNDELIM
fi

cleanUp
