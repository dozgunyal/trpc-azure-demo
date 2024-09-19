import NextError from 'next/error';
import Link from 'next/link';
import { useRouter } from 'next/router';

import type { NextPageWithLayout } from '~/pages/_app';
import type { RouterOutput } from '~/utils/trpc';
import { trpc } from '~/utils/trpc';

type PostByIdOutput = RouterOutput['post']['byId'];

function PostItem(props: { post: PostByIdOutput }) {
  const utils = trpc.useUtils();
  const resolvePost = trpc.post.resolve.useMutation({
    async onSuccess() {
      // refetches posts after a post is added
      await utils.post.byId.invalidate();
    },
  });

  const { post } = props;
  return (
    <div className="flex flex-col justify-center h-full px-8 ">
      <Link className="text-gray-300 underline mb-4" href="/">
        Home
      </Link>
      <h1 className="text-4xl font-bold">{post.title}</h1>
      <em className="text-gray-400">
        Created {post.createdAt.toLocaleDateString('en-us')}
      </em>

      <p className="py-4 break-all">{post.text}</p>

      {!post.resolved && (
        <div>
          <form
            onSubmit={async (e) => {
              /**
               * In a real app you probably don't want to use this manually
               * Checkout React Hook Form - it works great with tRPC
               * @link https://react-hook-form.com/
               * @link https://kitchen-sink.trpc.io/react-hook-form
               */
              e.preventDefault();
              try {
                await resolvePost.mutateAsync({
                  id: post.id,
                });
              } catch (cause) {
                console.error({ cause }, 'Failed to add post');
              }
            }}
          >
            <button
              className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
              type="submit"
              disabled={resolvePost.isPending}
            >
              Resolve
            </button>
            {resolvePost.error && (
              <p style={{ color: 'red' }}>{resolvePost.error.message}</p>
            )}
          </form>
        </div>
      )}
      <h2 className="text-2xl font-semibold py-2">Raw data:</h2>
      <pre className="bg-gray-900 p-4 rounded-xl overflow-x-scroll">
        {JSON.stringify(post, null, 4)}
      </pre>
    </div>
  );
}

const PostViewPage: NextPageWithLayout = () => {
  const id = useRouter().query.id as string;
  const postQuery = trpc.post.byId.useQuery({ id });

  if (postQuery.error) {
    return (
      <NextError
        title={postQuery.error.message}
        statusCode={postQuery.error.data?.httpStatus ?? 500}
      />
    );
  }

  if (postQuery.status !== 'success') {
    return (
      <div className="flex flex-col justify-center h-full px-8 ">
        <div className="w-full bg-zinc-900/70 rounded-md h-10 animate-pulse mb-2"></div>
        <div className="w-2/6 bg-zinc-900/70 rounded-md h-5 animate-pulse mb-8"></div>

        <div className="w-full bg-zinc-900/70 rounded-md h-40 animate-pulse"></div>
      </div>
    );
  }
  const { data } = postQuery;
  return <PostItem post={data} />;
};

export default PostViewPage;
