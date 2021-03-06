#Virtual Memory (vm.js)
Virtual memory provides something akin to operating system virtual memory systems with an emphasis on the paging infrastructure.  Unlike an operating system, flok has the concept of a grand-unified namespaced address space that extends the concepts of caching and semantics across asynchronous and even networked systems.  This vm systems is increadibly powerful because it allows you to create custom paging devices; this allows you to use one set of semantics to perform very complicated activities like pulling a news feed or list; having that news feed cached to disk automatically; etc.

This system has borrowed design concepts from `Git`'s distributed commit system for the synchronization mechanism, `FreeBSD's` layout of the `vm` paging-demand system, and Bell Lab's *Plan 9* operating system concept of networked files for communication.

Additionally, flok introduces a notification system that works with the demand paging schemes and caching schemes that allow you to grab data *now* and then be notified whenever a fresh copy is available from the server.

Notifications also extend naturally to controllers; use pages to perform `'ipc'` across controllers. This alows you to push information around your application in ways that the hierarchy may not take kind to.

Each pager belongs to a *namespace*; page faults hit a namespace and then the pager takes over. The pager can choose to service a request; or even throw an exception if a certain semantic is not supported in it's namespace; for example, you may want to disable write semantics for a network pager you called `net` because you expect people to make ordinary network requests.

Fun aside; Because of the hashing schemantics; this paging system solves the age old problem of ... how do you show that data has changed *now* when to be assured that you have perferctly synchronized data with the server?;... you need to do a 3-way handshake with the updates.  You could have a network server pager that supports writes but dosen't forward those to the network. That way, you can locally modify the page and then if the modifications were guessed correctly, the server would not even send back a page modification update! (Locally, the page would have been propogated as well).  In the meantime, after modifying the local page, you would send a real network request to the server which would in turn update it's own paging system but at that point, the server would check in with you about your pages, but miraculously, because you gussed the updated page correctly, no modifications will need to be made. You could even purposefully put a 'not_synced' key in and actually show the user when the page was correctly synchronized.

##Pages
###Example
```ruby
page_example = {
  _head: <<uuid STR or NULL>>,
  _next: <<uuid STR or NULL>,
  _prev: <<uuid STR or NULL>,
  _id: <<uuid STR>,
  entries: [
    {_id: <<uuid STR>>, _sig: <<random_signature for inserts and modifies STR>>},
    ...
  ],
  _hash: <<CRC32>>,
  __index: {
    entry_id: entry_index,
  }
}
```

  * `_head (string or null)` - An optional pointer that indicates a *head* page. The head pages are special pages that contain 0 elements in the entries array, no `_head` key, and `_next` points to the *head* of the list. A head page might be used to pull down the latest news where the head will tell you whether or not there is anything left for you to receive.
  * `_prev (string or null)` - The last element on this list. If `_prev` is non-existant, then this page is the endpoint of the list.
  * `_next (string or null)` - The next element on this list. If `_next` is non-existant, then this page is the endpoint of the list.
  * `_id (string)` - The name of this page. Even if every key changed, the `_id` will not change. This is supposed to indicate, semantically, that this page still *means* the same thing.  For example, imagine a page.  If all entries were to be **removed** from this page and new entries were **inserted** on this page, then it would be semantically sound to say that the entries were **changed**.
  * `entries`
    * An array of dictionaries. Each element contains a `_id` that is analogous to the page `_id`. (These are not the same, but carry the same semantics).  Entries also have a `_sig` which should be a generated hash value that changes when the entry changes.
  * `__index` - A dictionary mapping entry `_id` into an index of the `entries` array.
  * `_hash (string)` - All entry `_id's`, `_next`, `_prev`, the page `_id`, and `head` are hashed togeather. Any changes to this page will cause this `_hash` to change which makes it a useful way to check if a page is modified and needs to be updated. The hash function is an ordered CRC32 function run in the following order.  See [Calculating Page Hash](#calculating_page_hash).

------

## <a name='calculating_page_hash'></a>Calculating Page Hash
The `_hash` value of a page is calculated in the following way:
  0. `z = 0`
  1. `z = crc32(z, _head) if _head`
  2. `z = crc32(z, _next) if _next`
  2. `z = crc32(z, _prev) if _prev`
  3. `z = crc32(z, _id)`
  4. `_type` dependent
    * For `_type == 'array'` 
      * `z = crc32(z, entriesN._sig)` where N goes through all entries in order.
    * For `_type == 'hash'`
      * `R = crc32(0, entries[key]._sig)` is calcuated for each entry; R is an array.
      * `z = crc32(z, r0+r1+r2+...)` where `r0, r1, ...` are the elements of the array R we just calculated. This makes order not important.

If a key is null, then the crc step is skipped for that key.  e.g. if `_head` was null, then `z = crc32(0, _head)` would be skipped

Assuming a crc function of `crc32(seed, string)`

------

##Schemas & Data-Types

####`vm_diff_entry`
See [VM Diff](./vm/diff.md) for specific information.

###`Based page`
A based page contains the additional keys of `__base` and `__changes`, and these keys are not `null`. Optionally, it may contain the keys
`__base_sync` (which is also not null).
  * `__base` - A copy of the fully synchronized page (fully embedded)
  * `__changes` - An `vm_diff` array of changes from either `__base`, or if not `null` and not `undefined`, the `__base_sync` page.
  * `__base_sync` - An optional key, serves the same purpose as `__base`, but when synchronizing, the `__base_sync` is used for `__changes` as
      `__base_sync` holds a full copy of the currently in sync page.

Pages that are being synhronized are known as a `based in-sync page`.

##Configuration
The paging service may be configured in your `./config/services.rb`. You must set an array of pagers where each pager is responsible for a particular
namespace. See [VM Pagers](./vm/pagers.md) for more info.

```ruby
service_instance :vm, :vm, {
  :pagers => [
    {
      :name => "spec0",
      :namespace => "user",
      :options => {  //Passed to pager init function
      }
    }
  ]
}
```
Each pager can only be used once. In the future, using multiple copies of pagers would be a welcome addition. If you need to duplicate functionality of a pager,
you will want to copy your pager into a seperate piece of code and rename it so that it contains unique function names and variables, e.g. `my_pager0_read()` -> `my_pager1_read()`

  * Pager options
    * `name` - The name of the pager, this is used to create functions to each pager like `$NAME_read_sync`
    * `namespace` - The namespace of the pager, this is used during requests to the pager, each pager is bound to a namespace
    * `options` - A hash that is given to the pager's init function.


##Requests

###`watch`
This is how you **read a page** and **request notifications for any updates to a page**.
  * Parameters
    * `ns` - The namespace of the page, e.g. 'user'
    * `id` - Watching the page that contains this in the `_id` field
    * `sync (optional)` - If set to `true` then the cache read will be performed synchronously and if the cache misses, the disk will be read
        synchronously.  If the disk read fails, there will be no warning but this is an untested state and most likely, the next pager read will
        dispatch asynchronously. This isn't awful but you should never set the `sync` flag to be true on data that you have not already cached at
        some point. This is useful for profile loading, etc. so you don't have to delay on startup to display user name, etc. Multiple `watch`
        requests dispatched with `sync` flag within the same frame will incur no performance penalty, they will be coalesced into one disk read.
        Likewise, a `sync` watch request is perfectly acceptible to be called many times for a new controller needing the information. There is little
        performance benefit in locally caching the data and many drawbacks like not getting updates of changes.
  * Event Responses
    * `read_res` - Whenever a change occurs to a page or the first read. If `sync` is true, the page may be `{}` which indicates that no page existed
        when sync was called (really an illegal condition, you should never use sync unless it's cached)
    * Returns an immutable page in params

###`unwatch`
This is how you **unwatch** a page. For view controllers that are destroyed, it is not necessary to manually `unwatch` as the `vm` service will be notified on it's disconnection and automatically remove any watched pages for it's base pointer. This should be used for thingcs like scroll lists where the view controller is no longer interested in part of a page-list.

  * Parameters
    * `ns` - The namespace of the page, e.g. 'user'
    * `id` - Unwatch the page that contains this in the `_id` field

###`write`
Creates a new page or overrides an existing one. If you are modifying an existing page, it is imperative that you do not modify the page yourself and
use the modification helpers. These modification helpers implement copy on write (COW) as well as adjust sigs on specific entries and create ids for new entries.  The proper way to do it is (a) edit the page with the modification helpers mentioned in [User page modification helpers](#user_page_modification_helpers) and (b) perform a write request. This request updates the `_hash` field. Additionally, if you are creating a page, it is suggested that you still use the modification helpers; just use the `NewPage` macro insead of `CopyPage`. Additionally, modifiying a page after making a write request is prohibited as the `vm` service may alter your page.
  * Parameters 
    * `ns` - The namespace of the page, e.g. 'user'
    * `page` - The page to write (create or update)
  * Spec helpers
    * If in `@debug` mode, the variable `vm_write_list` contains an array dictionary of the last page passed to the pager (tail is latest).

###`read_sync`
Read from the disk synchronously, or memory if it exists, and return the value in `read_res`. This will not watch the page. Multiple read_syncs
in the same frame are allowed but discouraged as the order that pages are received back may not necessarily be the order they were synhronously
requested. This is because a cached page will be returned by the call stack while a synchronous read has to go through the event queue.
  * Parameters
    * `ns` - Namespace of the page
    * `id` - id of the page
  * Event Responses
    * `read_res`
      * `entire params` - The page that was retrieved (or `{}` if it dosen't exist)


###`invalidate`
Mark a page as invalid. This will clear the page from cache and notify any **controllers** watching the page via the `page_invalidated` message. The messaging
to controllers is done through the defer queue. Invalidation will then wipe the page from vm_cache and request that the page be deleted on the next page-out.
The pager will be notified via the `$pager.invalidate(page_id)` function. Pagers shall respond asynchronously to the invalidation request and assume
that the cache has already been wiped at this point.
  * Parameters.
    * `ns` - Namespace of the page
    * `id` - id of the page
  * Event Responses [For controllers watching the page]
    * `invalidated`
      * `ns` - The namespace of the page that was invalidated.
      * `id` - The id of the page that was invalidated

##Cache
See below with `vm_cache_write` for how to write to the cache. Each pager can choose whether or not to cache; some pagers may cache only reads while others will cache writes.  Failure to write to the cache at all will cause `watch` to never trigger. Some pagers may use a trick where writes are allowed, and go directly to the cache but nowhere else. This is to allow things like *pending* transactions where you can locally fake data until a server response is received which will both wipe the fake write and insert the new one. Cache writes will trigger `watch`; if you write to cache with `vm_cache_write` with a page that has the same `_hash` as a page that already exists in cache, no `watch` events will be triggered. Additionally, calling `vm_cache_write` with a non-modified page will result in no performance penalty. `vm_cache_write` notifies controllers asynchronously and is not effected by the `watch` flag on controllers.

###Pageout, Cache Synchronization, and Pager Synchronization
####Pageout Daemon
Cache will periodically be synchronized to disk via the `pageout` service. When flok reloads itself, and the `vm` service gets a `watch` the `vm` service will attempt to read from the `vm_cache` first and then read the page from disk (write that disk read to cache).

Pageout is embodied in the function named `vm_pageout()`. This will asynchronously write `vm_dirty` to disk and clear `vm_dirty` once the write has been commited. `vm_pageout()` is called every minute by the interval timer in this service.

####Pager Synchronization Daemon
When pagers get a write request, many pagers (as in all of them atm) mark the pages via `vm_pg_mark_needs_sync` which first calls the pagers `sync`
routine immediately and writes to the `vm_unsynced` hash. The hash is used like `vm_unsynced[ns][page_id]` which yields an integer value. The integer
value is either `0` or `1`. When `vm_pg_mark_needs_sync` is first called, the value is set to `0`. When the pager synchronization daemon
goes over the list in `vm_unsynced`; the daemon checks the integer field. If the integer is `0`, then the daemon only increments the integer. If the
integer is `1`, then the daemon notifies the pager with the `sync` action. The reason this is done is to avoid calling a pagers `sync` function too
soon as it is immediately called the first time when the pager calls `vm_pg_mark_needs_sync` on the page (usually at the end of the `write` action
for the pager). The pager de-registers the page via `vm_pg_unmark_needs_sync`.

The pager synchronization daemon is embodied in the function called `vm_pg_sync_wakeup`

###Datatypes & Structures (Opaque, do not directly modify)
  * `vm_cache` - The main area for storing the cache. Stored in `vm_cache[ns][key]`. Contains all namespaces by default with blank hashes.
  * `vm_dirty` - Pages recently written to cache go on the dirty list so that they may be written when the pageout handler runs. Dictionary contains map for `vm_dirty[ns][page._id] => page` for all dirty pages. Pages are removed from the dictionary when they are written in the pageout. Contains all namespaces by default with blank hashes.
  * `vm_evict` - Pages that need to be deleted from disk. `vm_evict[ns][page._id] => true`.  These pages are reaped during pageout. If the vm_evict has a page in it, but the page exists in vm_cache, then the page was added after the eviction request and should no longer be deleted
  * `vm_notify_map` - The dictionary used to lookup what controllers need to be notified about changes. Stored in `vm_notify_map[ns][id]` which yields an array of controller base pointers.
  * `vm_bp_to_nmap` - A dictionary that maps a `bp` key (usually from a controller) to a dictionary. This dictionary contains a mapping of `bp => ns => id` to an array that contains `[node, index]` where `node` is a reference to `vm_notify_map[ns][id]`. This inverted map must (a) provide a way for `unwatch` to quickly remove entries from itself and (b) provide a way for all entries in `vm_notify_map` to be removed when something (usually a controller) disconrnects.
    must support `unwatch` removal which we only receive the `bp`, `ns`, and `key`.
  * `vm_cache_write_sync_pending` - A hash mapping page_ids to controllers awaiting synchronous responeses, e.g.
      `vm_cache_write_sync_pending[page_id][0..N] := bp`. Usually set via the `watch` request
      during a sync call for disk reads or the synchronous `read_sync` request. The format for each element in the array is `{"page_id": [bp1, bp2], ...}`
  * `vm_pager_waiting_read` - A hash that maps `[ns][page_id]` into a hash that represents a the page that was trying to be written.
      needed to be read before notifying the pager. Multiple write attempts on the same page before the disk response will undefined behavior.
  * `vm_unsynced`
    * `vm_unsynced` - A hash that maps `vm_unsynced[ns][page._id]` to an integer that is either `0` or `1`. the vm sync daemon reads over this
        queue and `0` means that it was just requested via `vm_pg_mark_needs_sync` and needs to be incremented to `1`. `1` means that the vm sync
        daemon must contact the pager for the `sync` action. This will happend until the pager calls `vm_pg_unmark_needs_sync` which will remove it
        from this hash.
    * `vm_unsynced_is_dirty` - A boolean value that indicates whether the `vm_unsynced` needs to be paged-out to disk.
    * `vm_unsynced_paged_in` - A boolean that indicates whether the `vm_unsynced` needs to be paged in from disk (used once on wakeup)

##Helper Methods

###Functional
####Periodically called (daemons)
  * `vm_pg_sync_wakeup` - for all pages in `vm_unsynced`, the pagers are notified of a `sync` request
  * `vm_pg_sync_pagein` - If has not happend yet, the `vm_unsynced` table is loaded from disk via the the special namespace `__reserved__` and key
      `vm_unsynced`
  * `vm_pg_sync_pageout` - If the `vm_unsynced_is_dirty` is set, the `vm_unsynced` is written out to special namespace `__reserved__` and key
      `vm_unsynced`

####Page modification (assuming inputs are modifiable)
  * **Generic Page**
    * `vm_create_page(id)` - **this does not write anything to memory. It has no side effects except returning a hash**.
    * `vm_create_page()` -  Same as vm_create_page, but generates an id fore you.
    * `vm_copy_page(page)` - Creates a copy of the page. Only copies the `_head`, `_next`, `_prev`, `_id`, deep copy of `entries`, `_hash` and recalculates the `__index`
    * `vm_entry_with_id(page, entry_id)` - Searches a page for an entry with a particular id via the `__index` table. retruns `nil` if the entry is not found or
        a reference if the entry if it is found. The reference is **not** modifiable unless you call `vm_copy_page` first. Additionally, entries you
        added recently will not be available by this untli they are written to disk via `vm_cache_write`
    * `vm_del_entry_with_id(page, entry_id)` - Removes the entry from the page. If entry_id doesn't exist, nothing happends.
    * `vm_set_entry_with_id_key_val(page, key, entry_id, value)` - Set a particular key of an entry. This will also change the entries `_sig` field to
        a new random signature. If an entry with the id does not exist, it will be created.
    * `vm_rehash_page(page)` - Calculates the hash for a page and modifies that page with the new `_hash` field. If the `_hash` field does not exist, it
      will create it. Multiple calls are supported as it will recalculate the index as needed.
    * `vm_reindex_page(page)` - Recalculates the `__index` field of the page. If `__index` does not exist, it is added.
  * **Diff helpers**
    * See [VM Diff](./vm/diff.md) section on *Functional Kernel
  * **Commit helpers**
    * `vm_commit(older, newer)` - Modifications will be done to `newer`. It is assumed that `newer` is neither based nor changed. This is typical of a
        new page creation. It is assumed that `older` is either `[unbased, nochanges]`, `[unbased, changes]` or `[based[unbased, changes], changes]`.
       You would use this when a page is being written over a page that already exists. This will mark page as having changes.
          1. `older: [unbased, nochanges]` - `newer.__changes` will equal `vm_diff(older, newer)` and `newer.__changes_id` will be generated.
          2. `older: [unbased, changes]` - `newer.__base` will point to `older`. `newer.__changes` will equal `vm_diff(older, newer)` and
          `newer__changes_id` will be generated.
          3. `older: [based[unbased, changes], changes]]` - `newer.__base` will point to `older.__base`. Then `newer.__changes` will equal
          `vm_diff(older.__base, newer)` and `newer.__changes_id` will be generated.
    * `vm_rebase(newer, older)` - Modifications are done to `older`. It is assumed that `older` is not based nor changed. This is typical of a
        synchronized page from a server. It is assumed that `newer` is either `[unbased, nochanges]`, `[unbased, changes]` or `[based[unbased,
        changes], changes]`.
          1. `newer: [unbased, nochanges]` - No changes as `newer` does not contain any changes, therefore, `older` is the *truth*.
          2. `newer: [unbased, changes]` - `older` takes `newer.__changes` and `newer.__changes_id`. `older` then replays `older.__changes` on itself.
          3. `newer: [based[unbased, changes], changes]]`
            1. `older` takes `newer.__base.__changes` and `newer.__base.__changes_id`. `older` then replays `older.__changes` onto itself.
            2. `older` clones itself, let that clone be called `oldest`. `older.__base` is set to `oldest`.
            3. `older` replays `newer.__changes` onto itself.
            4. `older` then calculates `__changes` based off `oldest`.
    * `vm_mark_changes_synced(page, changes_id)` - Will reverse the steps of `vm_commit`. If the page has changes but is not based, then the changes are removed if the
        `__changes_id` of the page matches `changes_id`. If the page is based (implying the base page has changes and the page has changes as all base
        pages have changes), then if the `changes_id` matches the **base** `__changes_id` , the `__base` is removed from the page. If `changes_id`
        does not match in either of the cases, then nothing happends. This may happend if a synchronization errousouly comes in.
   * **Why do we have both `vm_rebase` and `vm_mark_changes_synced`?**
      * They are used under similar circumstances. You always `vm_mark_changes_synced` before calling `vm_rebase` on a page. The reasoning is that
          `vm_rebase` will assume that the cached page does not contain changes if they are present in `older`. If you didn't do this, then the
          cached page would be rebased and could contain changes even though it's already been rebased on an older page. E.g. `newer[changes, nobase]`
          rebased would be `older[changes, nobase]` where `changes` are equal on the `newer` and `older` but clearly that's incorrect. Another way of
          looking at it is that `vm_rebase` is saying that you are rebasing **on an authority** page and therefore needs no evidence that the page was
          an authority (which is why the `changes_id` can be stripped).  Method 3 of looking at it is that `vm_rebase` on a `newer[changes,
          based[changes, nobase]]` with `older` where `older` contains the changes of `newer.__base.__changes`, would result in `older` having
          `newer.__base.__changes` fast-forwarded over it, which it would already contain those changes.
###Non functional (functional as is in lambda calculus, or lisp (no **global** state changes but may modify parameters)
####Pager specific
  * `vm_cache_write(ns,  page)` - Save a page to cache memory. This will not recalculate the page hash. The page will be stored in `vm_cache[ns][id]` by.
  * `vm_pg_mark_needs_sync(ns, page_id)` - Marks that a page **in memory** is needing to be synced to the pager. This does a few things:
    * The page_id is added to the `vm_unsynced` with the value of 0; see above in `Datatypes & Structures` for details. i.e.
        `vm_unsynced[$PAGER_NS][page_id] = 0`
    *  the pager's routine of `sync` is called immediately. The page must exist in cache at this point.
  * `vm_pg_unmark_needs_sync(ns, page_id)` - Removes the page from the pending synchronization queue `delete vm_unsynced[$PAGER_NS][page_id]`). If
      it's not in the synchronization queue, then nothing will happend

### <a name='user_page_modification_helpers'></a>User page modification helpers (Controller Macros)
You should never directly edit a page in user land; if you do; the pager has no way of knowing that you made modifications. Additionally, if you have multiple controllers watching a page, and it is modified in one controller, those other controllers
will not receive the notifications of the page modifications. Once using these modifications, you must make a request for `write`. You should not use the information you updated to update your controller right away; you should wait for a `read_res` back because you `watched` the page you just updated. This will normally be performed right away if it's something like the memory pager.

Aside, modifying a page goes against the semantics of the vm system; you're thinking of it wrong if you think that's ok. The VM system lets the pager decide what the semantics of a `write` actually means. That may mean it does not directly modify the page; maybe it sends the write request to a server which then validates the request, and then the response on the watched page that was modified will then update your controller.

If you're creating a new page, please use these macros as well; just switch out `CopyPage` for `NewPage`.

####Per entry (OUT-DATED!!! use generic page helpers defined above)
  * `NewPage(type, id)` - Returns a new blank page; internally creates a page that has a null `_prev`, `_next`, `_head`, and `entries` array with 0 elements.  `_id` is generated if it is not passed.
  * `CopyPage(page)` - Copies a page and returns the new page. Internally this copies the entire page with the exception of the
      `_hash` field.
  * `EntryDel(page, eid)` - Remove a single entry from a page. (Internally this deletes the array entry).
  * `EntryInsertAtIndex(page, eindex, entry)` - Insert an entry at a specific index. This generates the `_sig` and `_id` for you.
  * `EntryInsertAtId(page, eid, entry)` - Insert an entry with a particular `_id`. This generates `_sig` for you. It will be put at the end of the
      array
  * `EntryMutable(page, eid)` - Set a mutable entry at a specific index which you can then modify. The signature is changed for you. You can not
      use this with dot syntax like `EntryMutable(page, eindex).id = 'foo'`, you may only get a variable.
  * `SetPageNext(page, id)` - Sets the `_next` id for the page
  * `SetPagePrev(page, id)` - Sets the `_prev` id for the page (not implemented)
  * `SetPageHead(page, id)` - Sets the `_head` id for the page

Here is an example of a page being modified inside a controller after a `read_res`
```js
on "read_res", %{
  //Copy page and modify it
  var page = Copy(params.page);
  
  //Remove first entry
  EntryDel(page, 0);
  
  //Insert an entry
  var my_entry = {
    z = 4;
  }
  EntryInsert(page, 0, my_entry);
  
  //Change an entry
  var e = EntryMutate(page, 1);
  e.k = 4;
  e.z = 5;
  
  //Write back page
  var info = {page: page, ns: "user"};
  Request("vm", "write", info);
}
```

##Pagers
See [Pagers](./vm/pagers.md) for information for pager responsibilities and how to implement them.

##Spec helpers
The variable `vm_did_wakeup` is set to true in the wakeup part of the vm service.
