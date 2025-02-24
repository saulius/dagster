import {gql, useApolloClient, useQuery} from '@apollo/client';
import {Colors, NonIdealState} from '@blueprintjs/core';
import {IconNames} from '@blueprintjs/icons';
import * as React from 'react';
import {RouteComponentProps, Link} from 'react-router-dom';

import {useDocumentTitle} from 'src/hooks/useDocumentTitle';
import {PipelineReference} from 'src/pipelines/PipelineReference';
import {Run} from 'src/runs/Run';
import {RunConfigDialog, RunDetails} from 'src/runs/RunDetails';
import {RunFragments} from 'src/runs/RunFragments';
import {RunStatusTag} from 'src/runs/RunStatusTag';
import {RunRootQuery} from 'src/runs/types/RunRootQuery';
import {Box} from 'src/ui/Box';
import {Group} from 'src/ui/Group';
import {PageHeader} from 'src/ui/PageHeader';
import {Heading} from 'src/ui/Text';
import {FontFamily} from 'src/ui/styles';

export const RunRoot = (props: RouteComponentProps<{runId: string}>) => {
  const {runId} = props.match.params;

  const {data, loading} = useQuery<RunRootQuery>(RUN_ROOT_QUERY, {
    fetchPolicy: 'cache-and-network',
    partialRefetch: true,
    variables: {runId},
  });

  const run =
    data?.pipelineRunOrError.__typename === 'PipelineRun' ? data.pipelineRunOrError : null;
  const snapshotID = run?.pipelineSnapshotId;

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        minWidth: 0,
        width: '100%',
        height: '100%',
        overflow: 'hidden',
      }}
    >
      <Box
        padding={{top: 16, bottom: 12, horizontal: 20}}
        border={{side: 'bottom', width: 1, color: Colors.LIGHT_GRAY3}}
        flex={{direction: 'row', alignItems: 'flex-start'}}
      >
        <PageHeader
          title={
            <Group direction="row" spacing={12} alignItems="flex-end">
              <Heading style={{fontFamily: FontFamily.monospace}}>{runId.slice(0, 8)}</Heading>
              {loading || !run ? null : (
                <div style={{position: 'relative', top: '-2px'}}>
                  <RunStatusTag status={run.status} />
                </div>
              )}
            </Group>
          }
          icon="history"
          description={
            <>
              <Link to="/instance/runs">Run</Link> of{' '}
              {run ? (
                <PipelineReference
                  pipelineName={run?.pipeline.name}
                  pipelineHrefContext={'repo-unknown'}
                  snapshotId={snapshotID}
                  mode={run?.mode}
                />
              ) : (
                <span>…</span>
              )}
            </>
          }
          metadata={run ? <RunDetails run={run} loading={loading} /> : null}
          right={run ? <RunConfigDialog run={run} /> : null}
        />
      </Box>
      <RunById data={data} runId={runId} />
    </div>
  );
};

const RunById: React.FC<{data: RunRootQuery | undefined; runId: string}> = (props) => {
  const {data, runId} = props;
  useDocumentTitle(`Run: ${runId}`);

  const client = useApolloClient();

  if (!data || !data.pipelineRunOrError) {
    return <Run client={client} run={undefined} runId={runId} />;
  }

  if (data.pipelineRunOrError.__typename !== 'PipelineRun') {
    return (
      <NonIdealState
        icon={IconNames.SEND_TO_GRAPH}
        title="No Run"
        description={'The run with this ID does not exist or has been cleaned up.'}
      />
    );
  }

  return <Run client={client} run={data.pipelineRunOrError} runId={runId} />;
};

const RUN_ROOT_QUERY = gql`
  query RunRootQuery($runId: ID!) {
    pipelineRunOrError(runId: $runId) {
      __typename
      ... on PipelineRun {
        id
        pipeline {
          __typename
          ... on PipelineReference {
            name
            solidSelection
          }
        }
        ...RunFragment
      }
    }
  }

  ${RunFragments.RunFragment}
`;
