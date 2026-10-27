<?php

declare(strict_types=1);

namespace Circle\Core;

final class Router
{
    /** @var array<string, array<int, array{pattern: string, handler: callable, middleware: string[]}>> */
    private array $routes = [];

    /** @var array<string, callable> */
    private array $middleware = [];

    /** @var string[] */
    private array $groupMiddleware = [];

    private string $prefix = '';

    public function registerMiddleware(string $name, callable $handler): void
    {
        $this->middleware[$name] = $handler;
    }

    /** @param string[] $middleware */
    public function group(string $prefix, array $middleware, callable $callback): void
    {
        $prevPrefix = $this->prefix;
        $prevMiddleware = $this->groupMiddleware;

        $this->prefix = $prevPrefix . $prefix;
        $this->groupMiddleware = array_merge($prevMiddleware, $middleware);

        $callback($this);

        $this->prefix = $prevPrefix;
        $this->groupMiddleware = $prevMiddleware;
    }

    /** @param string[] $middleware */
    public function get(string $path, callable $handler, array $middleware = []): void
    {
        $this->addRoute('GET', $path, $handler, $middleware);
    }

    /** @param string[] $middleware */
    public function post(string $path, callable $handler, array $middleware = []): void
    {
        $this->addRoute('POST', $path, $handler, $middleware);
    }

    /** @param string[] $middleware */
    public function put(string $path, callable $handler, array $middleware = []): void
    {
        $this->addRoute('PUT', $path, $handler, $middleware);
    }

    /** @param string[] $middleware */
    public function patch(string $path, callable $handler, array $middleware = []): void
    {
        $this->addRoute('PATCH', $path, $handler, $middleware);
    }

    /** @param string[] $middleware */
    public function delete(string $path, callable $handler, array $middleware = []): void
    {
        $this->addRoute('DELETE', $path, $handler, $middleware);
    }

    /** @param string[] $middleware */
    private function addRoute(string $method, string $path, callable $handler, array $middleware): void
    {
        $fullPath = $this->prefix . $path;
        $pattern = $this->pathToPattern($fullPath);
        $allMiddleware = array_merge($this->groupMiddleware, $middleware);

        $this->routes[$method][] = [
            'pattern' => $pattern,
            'handler' => $handler,
            'middleware' => $allMiddleware,
        ];
    }

    /**
     * `{token}` matches an opaque URL-safe token, `{mediaId}`/`{uploadId}` a UUID,
     * `{size}` a media size name; every other placeholder is a numeric id.
     */
    private function pathToPattern(string $path): string
    {
        $path = rtrim($path, '/') ?: '/';
        $regex = preg_replace_callback(
            '#\{([a-zA-Z_]+)\}#',
            static fn (array $m): string => match ($m[1]) {
                'sessionId' => '(?P<sessionId>[a-f0-9]{32})',
                'token' => '(?P<token>[A-Za-z0-9_-]{16,128})',
                'mediaId', 'uploadId' => '(?P<' . $m[1] . '>[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12})',
                'size' => '(?P<size>thumb|medium|full)',
                'kind' => '(?P<kind>avatar|cover)',
                default => '(?P<' . $m[1] . '>[0-9]{1,19})',
            },
            $path
        );
        return '#^' . $regex . '$#';
    }

    public function dispatch(Request $request): void
    {
        $routes = $this->routes[$request->method] ?? [];

        foreach ($routes as $route) {
            if (preg_match($route['pattern'], $request->path, $matches) === 1) {
                $params = array_filter($matches, 'is_string', ARRAY_FILTER_USE_KEY);
                $request = $request->withParams($params);

                $handler = $this->buildPipeline($route['handler'], $route['middleware']);
                $handler($request);

                // Every handler must send a response; reaching here is a bug.
                throw new \LogicException('Route handler returned without sending a response.');
            }
        }

        Response::notFound('Endpoint not found');
    }

    /** @param string[] $middlewareNames */
    private function buildPipeline(callable $handler, array $middlewareNames): callable
    {
        $pipeline = $handler;

        foreach (array_reverse($middlewareNames) as $name) {
            if (!isset($this->middleware[$name])) {
                throw new \LogicException("Unknown middleware: {$name}");
            }
            $mw = $this->middleware[$name];
            $next = $pipeline;
            $pipeline = static function (Request $request) use ($mw, $next): void {
                $mw($request, $next);
            };
        }

        return $pipeline;
    }
}
