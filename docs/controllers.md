#Controllers
Controllers are a lot like the controllers from `MVC` triads. They are the heart of your user-defined behavior in the same way rails controllers define your web-application.

See [Client API](./client_api.md) for details on the functions available to controllers.

##Kernel & Client Controllers
There are two types of controllers.  One type is a universal `flok user controller` (**fuc**) that manages state information, the view hierarchy, and is written in javascript; the other type is present on your device, the `device view controller` (**dvc**). The `device view controller` expresses the appereance of the state and view names from `flok user controller`.  The `device view controller` also sends events to the `flok user controller` when an action is commited, like a `button_clicked` event.

##Events
Events can be sent bi-directionally from the `fuc` and `dvc` via the [Event Module](./mod/event.md).  Controller communication is done entirely over the event system with the exception of `if_init_controller` to bootstrap the controller, and the views which are managed by the [UI Module](./mod/ui.md) by the `fuc`.

####`fuc => dvc`
When an event is sent from the `fuc`, the event pointer should be interpreted as the opaque device defined address of the `dvc`. The `dvc` would have been given in `if_init_controller` and the device is required to record that information and dispatch `if_event` messages to the matching `dvc`.

####`dvc` => `fuc`
When an event is sent from `dvc`, then `fuc` calls an appropriate `on` handler to manage the event. If there are no `on` handlers that can take the
event, the event is passed to the `event_gw` (event gateway) of the `controller_info` structure [See datatypes](./datatypes.md) for more information
on the structure. If `event_gw` is `null`, then the event is ignored.

###Writing a `flok user controller (fuc)`
Let's write a `fuc` controller that has 2 tabs and a content area. The view is implicitly the same name of the controller, in this case it would be
`tab_controller`

```ruby
controller "tab_controller" do
  spots "content"
  services "my_service", "vm" #See docs on services for what this means

  #Global on_entry, will only be run once on the first action. If chooose_action
  #is used, this is run before choose_action, but still only once throughout this
  #controller's lifetime
  on_entry %{
  }

  #You can also define macros for shared action traits
  macro :my_macro do
    on "shared_clicked", %{
      Goto("home")
    }
  end

  #More advanced macros can use the `current_action` to check
  #which action you are on
  macro :my_nav_macro do
    on "home_clicked", %{
      if (current_action !== "home") {
        Goto("home")
      }
    }

    on "about_clicked", %{
      if (current_action !== "home") {
        Goto("about")
      }
    }
  end

  #Navigation stacks often have multiple entry points, 'back' may differ
  #in action depending on whether it is the highest in the stack, you
  #may use the 'push_count' variable to get the current level of the
  #hierarchy you are on
  macro :my_stack_macro do
    on "back_clicked", %{
      //If the push_level is 0, then we cannot Pop
      if (push_count === 0) {
        Raise("back_clicked");
      } else {
        Pop();
      }
    }
  end

  #Optional
  #Called after on_entry, but before any action is entered. This is a pseudo
  #action and assumes that everything you do inside will be performed fully
  #synchronously. This action will not notify your view hierarchy that the
  #action has been entered. Only supports Request and Goto macros. Embedding will
  #result in undefined behavior. If you decide to not use choose_action then
  #the first action will be the action that is run first
  choose_action do
    on_entry %{
      var info = {ns: "session", id: "session"};
      Request("vm", "read_sync", info);
    }

    #Like every normal action, choose_action supports getting events
    #Here we are checking a synchronous read for the session information
    #You *must* use only synchronous events here
    on "read_sync_res", %{
      if (params.page === null) {
        Goto("home");
      } else {
        Goto("about");
      }
    }
  end

  #Actions are independent of one another, you may not name an action "choose_action"
  #The home tab
  action "home" do
    #Macros can be called via their name
    my_macro

    on_entry %{
      Embed("home_controller", "content", {});
    }
    
    on "about_clicked", %{
      Goto("about");
    }
  end
  
  #The about tab
  action "about" do
    on_entry %{
      Embed("about_controller", "content", {});
    }
    
    on "home_clicked", %{
      Goto("home");
    }
  end
end
```

###Sharing
You may share a set of information by adding the `share` or `share_spot`.  You can import shared information by using `map_share`, or `map_shared_spot`.
e.g.

```ruby
controller :example do
  #Allows you to use the shared.user object (its blank by default)
  share "user"
  spots "content"
  share_spot "content" => "example.content"

  action :index do
    on_entry %{
      shared.user.name = "foo"
    }
  end
end

controller :example2 do
  #Allows you to use the shared.user object (its blank by default)
  map_share "user"

  map_shared_spot "example.content"

  action :index do
    on_entry %{
      //Can access shared.user assuming that it's embedded within the example controller

      //Remote embed
      Embed("example3", "example.content", {});
    }
  end
end
```

###`action` types
Most actions are created with just `action`.  However, there is the `sticky_action` which will not destroy it's views upon a change via `Goto` but will destroy it's views in a change in a `Pop`.
Instead, the views are hidden/unhidden when actions are done multiple times.

###The different segue types
Including Goto, there are several different kinds of segue types.  Each has it's own semantics w.r.t the destruction and level of the destination view.

  1. `Goto` - All views in spots that were filled in the previous action will be removed before completing the Goto statement.
  2. `Push` - A copy of the view-controller's subviews (views in spots) will be maintained but the event receiving will still act like `Goto`, as in the destinatino action is subsumes the current action.

Additionally, an action may be marked `sticky`. E.g. `sticky_action "home" do`. Sticky action's will not call `on_entry` during the second jump for **Goto**. Pushing a sticky action
will result in undefined behaviour. This acts as a *lazy* loader where pages are loaded once and then kept around (but hidden away).

###`fuc` API
  See [Client API](./client_api.md)

###`fuc` registrations
When a `fuc` is initialized, there are various things that are configured that must be cleaned up when the `fuc` is torn down.

###`fuc` internals
####View Init Procedure
  1. `if_init_view`
  2. `if_controller_init`
  3. `if_attach_view`

####Registrations
  * Entire `fuc` lifetime
    * The `tp` of the `fuc` contains the `controller_info`
    * The `root_view` of the `fuc`
    * The entry for the `fuc tp` in `event vector table`
  * Per action
    * A set of embeds for more `fuc`

###Internals
This controller is put inside the `ctable` for all the things that don't change. see [datatypes](./datatypes.md) for information on the layout of the ctable.
for each controller.

In order for changes to be represented in a controller, a controller must be *initialized*. Unlike rails, Flok allows you to use many controllers within one-another,
and many instances of the same controller if you wish. 

Controller initialization is done via `_embed` or the `embed` macro if you are inside a controller. Embedding
  1. Requests a set of sequential pointers via `tels`, `n(spots)`.  `main` is always a spot, so there is always at least two pointer. The first pointer is the view controller itself `vc`, and the second is the `main` (root) view.
    * Spots looks like ['vc', 'main', ...]
  2. Initializes the root view of the controller with `bp+1` and retrieve the spots array from the controller `main` + whatever you declared in `spots`
  3. Attaches that view to the `bp+2+spots.indexOf(spot)` (which is a tele-pointer) given in the embed call.
  4. Sets up the view controller's info structure.
  5. Explicitly registers the view controller's info via `tel_reg_ptr(info, base)`
  6. Configures the `evt` to receive events at the base pointer
  6. Invokes the view controllers `on_entry` function with the info structure.
