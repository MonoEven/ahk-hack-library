# Lifecycle and ownership

This document defines who owns what in the cnumpy <-> AHK bridge.  The
guiding rule is: **cnumpy keeps ownership of its arrays; AHK owns every
object this bridge creates.**

## Ownership map

| API | Result | Owner | Source array |
| --- | --- | --- | --- |
| `CnpBridge.ToAhk` | nested AHK `Array` | AHK (deep copy) | unchanged |
| `CnpBridge.ToBuffer` | AHK `Buffer` | AHK (copied bytes) | unchanged |
| `CnpBridge.View` | `CnpView` | borrowed, with strong back-reference | must stay alive via the view |
| `CnpBridge.FromAhk` | `Numpy.NdArray` | cnumpy (new array) | AHK input unchanged |
| `CnpBridge.FromAhkFast` | `Numpy.NdArray` | cnumpy (new array) | AHK input unchanged |
| `CnpBridge.FromBuffer` | `Numpy.NdArray` | cnumpy (`cnp_frombuffer` copies) | AHK `Buffer` keeps ownership |

`Numpy.NdArray` owns its `CnpArray` and calls `cnp_ahk_free` in `__Delete`
when the last wrapper reference is released.

## CnpView rules

`CnpView` is the zero-copy path.  It does **not** call `cnp_ahk_free` and
does **not** take ownership of cnumpy memory.  Instead:

1. The view stores a strong AHK reference to the owning `Numpy.NdArray`
   (`view.Owner`), so the wrapper cannot free the array while the view lives.
2. Keep the view (or any other `NdArray` reference) alive for as long as the
   underlying pointer is needed.  Dropping both the original wrapper and the
   view frees the array normally.
3. Writes through `CnpView.Set` are allowed only when the array is writeable
   (`CNP_ARRAY_WRITEABLE`); otherwise the view throws.
4. A view observes cnumpy mutations and vice versa, because both sides point
   at the same memory.  This is the intended zero-copy contract.

## Anti-patterns

- Storing `view.Ptr` in a global and using it after `view` is released.
- Letting cnumpy free or resize an array while a view is active.  The bridge
  never does this itself; user code must not either.
- Assuming `CnpBridge.ToAhkFast` writes to the source.  It is a deep copy;
  only `CnpView` is a live view.

## Future native ownership

`CnpArray` already carries `owner` and `owner_release` fields.  A later
milestone can hand native ownership to an AHK object (or a custom
`CnpView` variant) through those fields, enabling safe transfer of cnumpy
buffers out of the cnumpy lifetime without changing cnumpy itself.
