from django.urls import path, include

urlpatterns = [
    path('webhook/', include('api.urls')),
]
