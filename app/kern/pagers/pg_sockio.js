//Configure pg_sockio
<% [0].each do |i| %>
  function pg_sockio<%= i %>_init(ns, options) {
    pg_sockio<%= i %>_ns = ns;

    if (options.url === undefined) {
      throw "pg_sockio<%= i %> was not given a url in options";
    }

    <% if @debug %>
      pg_sockio<%= i %>_spec_did_init = true;
    <% end %>

    //Destination for events sent from the sockio driver
    function pg_sockio<%= i %>_xevent_handler(ep, ename, einfo) {
      if (ename === "update") {
        vm_transaction_begin();
        vm_cache_write(pg_sockio<%= i %>_ns, einfo.page);
        vm_transaction_end();
      } else {
        <% if @debug %>
        throw "pg_sockio<%= i %>_xevent_handler received an event called: " + ename + "that it does not know how to handle. This event should never have even been forwarded, but you may have missed adding the handler code if you did request a forward"
        <% end %>
      }
    } 

    //Register the base address for the socket and the destination for events
    pg_sockio<%= i %>_bp = tels(1);
    reg_evt(pg_sockio<%= i %>_bp, pg_sockio<%= i %>_xevent_handler);

    SEND("net", "if_sockio_init", options.url, pg_sockio<%= i %>_bp);

    //Signal that the socket.io driver should forward all events to the socket defined by pg_sockio{N}_bp
    //to the endpoint (with the same reference)
    SEND("net", "if_sockio_fwd", pg_sockio<%= i %>_bp, "update", pg_sockio<%= i %>_bp);
  }

  function pg_sockio<%= i %>_watch(id, page) {
    var info = {
      page_id: id
    };
    SEND("net", "if_sockio_send", pg_sockio<%= i %>_bp, "watch", info);
  }

  function pg_sockio<%= i %>_unwatch(id) {
  }

  function pg_sockio<%= i %>_write(page) {
  }
<% end %>