controller :my_controller do
  spots "hello", "world"
  services :spec

  action :my_action do
    on_entry %{
    }
  end
end
