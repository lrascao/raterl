[![Build Status](https://travis-ci.org/lrascao/raterl.svg?branch=master)](https://travis-ci.org/lrascao/raterl)

# raterl

Erlang flow control application heavily inspired in `jobs` and `ratx`,
ETS based bypasses the `jobs_server` single process bottleneck while
providing `rate` and `counter` flow control.

## Supports

## TODO

  * Queues
  * Modifiers

## Examples

### Rate flow control

A typical use case is restricting the number of logins per second
on a system, you'd start by the configuration:

```erlang
[{raterl, [
    {queues, [
        {login_requests, [
            {regulator, [
                {name, max_login_rate}, 
                {type, rate},
                {limit, 100}   %% ensures that we get no more than x logins per second
            ]}
        ]}
    ]}
  ]
}].
```

Then on the code you ask permission from `raterl` before accepting a login:

```erlang
    case raterl:run(login_requests, {rate, max_login_rate}, fun () -> Ret end) of
        limit_reached ->
            {error, throttled};
        Ret -> Ret
    end;
```

Build
-----

    $ rebar3 compile

