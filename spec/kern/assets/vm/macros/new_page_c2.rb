controller :controller do
  action :index do
    on_entry %{
      page = NewPage("array", "test");
    }
  end
end
