controller :my_controller do
  action :my_action do
    on_entry %{
    }

    on "test_event", %{
      Goto("my_other_action")
    }
  end

  action :my_other_action do
    on_entry %{
    }
    on "hello", %{
    }
  end
end
