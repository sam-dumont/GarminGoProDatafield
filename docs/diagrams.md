# Garmin GoPro Datafield – Diagrams

This document collects all mermaidjs diagrams for easy reference and visualization.

---

## Architecture Diagram

```mermaid
flowchart TD
    A[Garmin Datafield UI] -- User Actions --> B[GoPro BLE Delegate]
    B -- BLE Commands --> C[GoPro Camera]
    C -- Status/Notifications --> B
    B -- State Updates --> A
    B -- Properties/Storage --> D[Garmin Properties/Storage]
```

---

## BLE Communication Flow

```mermaid
sequenceDiagram
    participant Garmin as Garmin Datafield
    participant GoPro as GoPro Camera
    Garmin->>GoPro: Scan & Pair
    GoPro-->>Garmin: BLE Advertising
    Garmin->>GoPro: Connect & Subscribe
    GoPro-->>Garmin: Notifications (Status, Settings)
    Garmin->>GoPro: Send Command (e.g., Start Rec)
    GoPro-->>Garmin: Command Response
    Garmin->>GoPro: Query Status
    GoPro-->>Garmin: Query Response
```

---

## State Machine

```mermaid
stateDiagram-v2
    [*] --> Searching
    Searching --> Connecting: GoPro found
    Connecting --> Connected: BLE paired
    Connected --> Sleep: Camera sleeps
    Sleep --> Searching: Wakeup
    Connected --> Searching: Disconnect/Lost
```
