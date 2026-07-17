FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /workspace
COPY . .
RUN flutter pub get --directory services/shopping_allocation_planner
CMD ["dart", "run", "services/shopping_allocation_planner/bin/server.dart"]
