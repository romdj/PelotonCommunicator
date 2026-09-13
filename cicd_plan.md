so one thing is that in the build step I'd like to see in parallel:
- All services builds
- All separate components (e.g. front-end component/folder)

The next stage gate would be unit + component testing for all those same components
- All services unit tests + component tests (separate step)
- All additional separate components (e.g. front-end component/folder): unit tests ; component tests

The next steps/gates would be shown in a common way since they are shared elements; each line is a separate gate
- Integration tests 
- E2E tests
- Security audit

Please rephrase that (long) request so I know we're on the same page then expose your plan on how you'd do this.

Any AI Agents we could enable too in the gh pipeline?

