import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';

describe('Pagination links component', () => {
  const template = `
    <template #actions>
      Actions go here
    </template>
  `;

  describe('Ordered Layout', () => {
    let wrapper;

    const createWrapper = () => {
      wrapper = shallowMountExtended(PageHeading, {
        scopedSlots: {
          actions: template,
        },
        propsData: {
          heading: 'Page heading',
        },
      });
    };

    const heading = () => wrapper.findByTestId('page-heading');
    const actions = () => wrapper.findByTestId('page-heading-actions');

    beforeEach(() => {
      createWrapper();
    });

    describe('rendering', () => {
      it('renders the correct heading', () => {
        expect(heading().text()).toBe('Page heading');
        expect(heading().classes()).toEqual(['gl-heading-1', '!gl-m-0']);
        expect(heading().element.tagName.toLowerCase()).toBe('h1');
      });

      it('renders its action slot content', () => {
        expect(actions().text()).toBe('Actions go here');
      });
    });
  });
});
