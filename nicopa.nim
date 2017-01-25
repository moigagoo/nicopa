##[
*******************************
Nim COncurrency and PAralellism
*******************************

Demonstration of concurrency and parallelism in Nim.

Compile and run::

  $ nim c -r nicopa

In a directory without `config.nims`::

  $ nim c --threads:on -r nicopa

Read more:

- “Nim in Action”, chapters 3 and 6.
- `Documentation <http://nim-lang.org/docs/lib.html>`__ on the imported modules (see below).
- http://nim-lang.org/docs/manual.html#threads

]##

import os, strutils, sequtils
import md5
import asyncdispatch, httpclient
import threadpool


proc calculateMd5*(content: string): string =
  ## Long CPU-bound task.

  echo "Calculating hash..."
  sleep 1000
  result = content.getMD5()
  echo "Done!"


proc downloadBlocking*(version: string): string =
  ## Blocking version of the download proc. Proc blocks until the archive is
  ## fully downloaded.

  echo "Dowloading $#..." % version

  let
    client = newHttpClient()
    archive = "nim-$#.tar.xz" % version
    url = "http://nim-lang.org/download/" & archive

  result = client.getContent(url)
  archive.writeFile result

  echo "Finished downloading $#." % version

proc downloadAsync*(version: string): Future[string] {.async.} =
  ## Non-blocking version of the download proc. Returns a `Future` immediatelly
  ## when called. `await` marks a point where the event loop can pass control
  ## to another async proc.

  echo "Downloading $#..." % version

  let
    client = newAsyncHttpClient(sslContext = nil) # ignore `sslContext = nil`, fixed by https://github.com/nim-lang/Nim/pull/5265.
    archive = "nim-$#.tar.xz" % version
    url = "http://nim-lang.org/download/" & archive

  result = await client.getContent(url)
  archive.writeFile result

  echo "Finished downloading $#." % version


when isMainModule:
  let versions = [
    "0.15.0",
    "0.15.2",
    "0.16.0"
  ]

  #[ Download versions one after another.
  for version in versions:
    discard downloadBlocking version
  ]#

  #[ Download versions asynchronously.
  discard waitFor all versions.map(downloadAsync)
  ]#

  # Download versions asynchronously and calculate hash for each one
  # in a separate thread.

  var hashes: seq[FlowVar[string]] = @[] # `FlowVar` is like a `Future` but for threads

  for content in waitFor all(versions.map(downloadAsync)):
    hashes.add spawn content.calculateMd5() # `spawn` runs a proc in a separate thread

  for hash in hashes:
    echo ^hash # block until thread completes
