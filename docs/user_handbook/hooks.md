#Hooks (User Guide)

## What problems do hooks solve?
##### There are two questions that *Hooks* were designed to solve.

1. Animation segues.  When a controller switches actions, often time it is swapping out view controllers. Adding animations at this time would be the optimal time to do so.  However, different clients, take blackberry and iOS, may either have fully-automated-animations, gesture controlled animations, cancelable-animations, synchronous-blocking, and the list goes on-and-on. Clearly, animations are handled differently on each platform, so how do we allow each platform to manage animation-segues?
2. There are times when a client, e.g. chrome, need to support semantics that are platform dependent.  *For example*, you may need the back button in your web client to trigger a view controller to go back a page. However, this semantic does not make much sense when you have multiple view controllers; e.g. What view controller receives the back clicked event?

##### Additionally, these questions must be solved with these constraints
1. Allowing the client to choose interception points at runtime would be prohibitively slow.  Therefore, care should be taken to make sure hooks are as static as possible and do not add un-necessary runtime overhead.

-------

##### How hooks solves these problems:
*Hooks* solves these questions and constraitns by allowing the user to define triggers in their project under `./config/hooks.rb` using a *DSL* which in-turn notifies the client. The client then handles each hook in an appropriate fashion.

## Hooking by example with `./config/hooks.rb`

**Here is an example of a `./config/hooks.rb` which tells flok to notify the client that the `supports_back_clicked` hook triggered whenever a controller instance of a `"my_controller"` controller switches to an action via Goto that has an event handler defined with `back_clicked`:**

```ruby
# $USER_POJECT_ROOT/config/hooks.rb
hook :goto => :supports_back_clicked do
  #Selectors (Each selector reduces the toal search area, if you have no selectors, it's like SELECT *)
  to_action_responds_to? "back_clicked"
  controller_name "my_controller"
  
  #Configuration methods
  is_sync
end
```

**The basic format of each hook looks like:**
```ruby
hook :hook_generator_name => :hook_notification_name do
  #Selector methods & Configuration specific to the hook generator
end
```

Selectors for each hook generator create more specific requirements for a trigger. By convention, all hook generators, if supplied no selector arguments will select all possible.  **For example, this would hook all Goto statements in all controllers**:
```ruby
hook :hook_generator_name => :hook_notification_name do
end
```

## Handling hook notifications in the client
---
The client, in-turn must handle the hook notification, in this example, the hook notification is named `supports_back_clicked`. The hook notifications typically includes a set of parameters, but the parameters are dependent on the *hook generator* used.  In the above example, we are using the `goto` hook generator. See below for the different `hook generators` specifics.

** See client docs for how to handle hook notifications, here is an example in pseudo code: **
```ruby
handleHook("supports_back_clicked", function(hookInfo) {
  var to_action_name = hookInfo.to_action_name;
});
```

## Hook generators

  * `goto` - Intercept `Goto` transitions and when a controller first loads (by virtue that a controller runs `Goto` when it first is initialized)
    * `DSL Selectors`
      * `to_action_responds_to? "event_name"` - Whenever a controller switches **to** an action that contains an `on "event_name", %{...}` handler
      * `from_action_responds_to? "event_name"` - Whenever a controller switches **from** an action that contains an `on "event_name", %{...}` handler
      * `controller "controller_name"` - Only applies to controllers with the name `"controller_name"`

## How the hook generators are defined & hooking internals
See [Kernel Handbook | Hooks](../kernel_handbook/hooks.md)

##How hooks are compiled into the kernel
The user's `./config/hooks.rb` file is compiled and then evaluated statically to get a listing of all the controllers that the hooks can apply to. Then the compiler goes over each controller
and inserts code at particular hook detection points; the nature of the insertions is up to the particular hooking context.

##Synchronous vs Asynchronous Hooks
Whether a hook is synchronous or not synchronous depends entirely on the type of hook in question. An example of a possible synchronous hook is a hook jkkkkkkkkkk..j

##Hooking check points
Each controller has a plethora of functions that determine it's lifetime and behaviours. These functions include the actions of creation, destruction, embedding, pushing actions, talking to services, etc.
These functions are built into the ctable entry for each controller and possible controller related functions like _embed. Each controller entry point is marked with a special comment marker that has
the following JSON format:

```ruby 
//HOOK_ENTRY[my_name] {foo: "bar"}...
```
The name is the hook name and the params is context specific inforamtion the compiler has embedded. Live variables that are in the context of the hook detection point are described in each hook detection point below.

  * `controller_will_goto` - The controller is about to invoke the Goto macro and switch actions or it has just entered the first action from choose_action (which is a Goto).
    * params (static generated)
      * `controller_name` - The controller name that this entry effects
      * `from_action` - The name of the action we are coming from
      * `to_action` - The name of the action we are going to
    * Useful (dynamic) variables
      * `old_action` - The previous action, equal to `from_action` but in dynamic form. If there is no action, this is set to `choose_action`. Not sure why you would use this
      * `__info__.action` - The name of the new action
  * `${controller_name}_did_destroy` - The controller has *just* been destroyed

##Hooks Compiler
The hooks compiler is able to take the hook entry points and inject code into them via a set of `HooksManifestEntries` which are bound togeather via a `HooksManifest`. The actual
compiler only takes the original source code, the `HooksManifest` and then spits out a version that no longer contains the special hook entry comments and contains any
injected hooking code.


##User Hook Generators

###./config/hooks.rb
The hooks configuration file contains the user's DSL hooks. This file is not compiled directly by `HooksManifest` but rather many intermediate `UserHookGenerator` are
used to parse the `./config/hooks.rb` and this conversion is orchestrated by the singleton `UserHooksToManifestOrchestrator`. Each `UserHook` is defined in the `./lib/user_hook_generators.rb`
and are never meant to directly be created by users.