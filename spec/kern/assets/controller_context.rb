controller :my_controller do
  action :index do
    on_entry %{
      context.hello = 'world';
    }
  end
end
