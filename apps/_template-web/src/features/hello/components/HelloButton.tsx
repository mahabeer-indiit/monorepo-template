import { Button } from '@template/ui';

type HelloButtonProps = {
  onGreet: () => void;
};

export function HelloButton({ onGreet }: HelloButtonProps) {
  return (
    <Button onClick={onGreet} variant="default">
      Say hello
    </Button>
  );
}
