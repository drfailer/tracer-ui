# Tracer UI

## Tracer file format

- Timestamps in ns (`u64`).
- The fields `group`, `timeline` and `infos` are strings that are preceded by
  the number of characters.

### Event format

```
EV::[<tp:8>][<group:8+size>][<timeline:8+size>][<infos:8+size>]
```

### Duration format

```
DU::[<tp1:8><tp2:8>][<group:8+size>][<timeline:8+size>][<infos:8+size>]
```


